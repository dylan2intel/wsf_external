#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
from __future__ import absolute_import, division, print_function, unicode_literals
import sys
import platform
import subprocess
import os
from os.path import expanduser
import re
import glob
import numpy as np
from argparse import ArgumentParser, REMAINDER
from argparse import RawTextHelpFormatter
import logging
from datetime import datetime

format_str = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
logging.basicConfig(level=logging.INFO, format=format_str)
logger = logging.getLogger(__name__)


class CPUinfo():
    '''
    Get CPU inforamation, such as cores list and NUMA information.
    '''
    def __init__(self):

        self.cpuinfo = []
        if platform.system() == "Windows":
            raise RuntimeError("Windows platform is not supported!!!")
        elif platform.system() == "Linux":
            args = ["lscpu", "--parse=CPU,Core,Socket,Node"]
            env_lang = os.getenv('LANG', 'UNSET')
            os.environ['LANG'] = 'C'
            lscpu_info = subprocess.check_output(args, env=os.environ, universal_newlines=True).split("\n")
            if env_lang == 'UNSET':
                del os.environ['LANG']
            else:
                os.environ['LANG'] = env_lang

            # Get information about  cpu, core, socket and node
            for line in lscpu_info:
                pattern = r"^([\d]+,[\d]+,[\d]+,[\d]?)"
                regex_out = re.search(pattern, line)
                if regex_out:
                    self.cpuinfo.append(regex_out.group(1).strip().split(","))
            assert len(self.cpuinfo) > 0, "cpuinfo is empty"
            self.get_socket_info()

    def get_socket_info(self):
        idx_active = 3
        if self.cpuinfo[0][idx_active] == '':
            idx_active = 2
        self.nodes = int(max([line[idx_active] for line in self.cpuinfo])) + 1
        self.node_physical_cores = []  # node_id is index
        self.node_logical_cores = []   # node_id is index
        self.physical_core_node_map = {}  # phyical core to numa node id
        self.logical_core_node_map = {}   # logical core to numa node id
        self.physical_to_logical = {}

        for node_id in range(self.nodes):
            cur_node_physical_core = []
            cur_node_logical_core = []
            for line in self.cpuinfo:
                nid = line[idx_active] if line[idx_active] != '' else '0'
                if node_id == int(nid):
                    if int(line[1]) not in cur_node_physical_core:
                        cur_node_physical_core.append(int(line[1]))
                        self.physical_core_node_map[int(line[1])] = int(node_id)
                    else:
                        self.physical_to_logical[int(line[1])] = int(line[0])
                    cur_node_logical_core.append(int(line[0]))
                    self.logical_core_node_map[int(line[0])] = int(node_id)
            self.node_physical_cores.append(cur_node_physical_core)
            self.node_logical_cores.append(cur_node_logical_core)

    def node_nums(self):
        return self.nodes

    def physical_core_nums(self):
        return len(self.node_physical_cores) * len(self.node_physical_cores[0])

    def logical_core_nums(self):
        return len(self.node_logical_cores) * len(self.node_logical_cores[0])

    def get_node_physical_cores(self, node_id):
        if node_id < 0 or node_id > self.nodes - 1:
            logger.error("Invalid node id")
        return self.node_physical_cores[node_id]

    def get_node_logical_cores(self, node_id):
        if node_id < 0 or node_id > self.nodes - 1:
            logger.error("Invalid node id")
        return self.node_logical_cores[node_id]

    def get_all_physical_cores(self):
        return np.array(self.node_physical_cores).flatten().tolist()

    def get_all_logical_cores(self):
        return np.array(self.node_logical_cores).flatten().tolist()

    def numa_aware_check(self, core_list):
        '''
        Check whether all cores in core_list are in the same NUMA node. cross NUMA will reduce perforamnce.
        We strongly advice to not use cores on different nodes.
        '''
        cores_numa_map = self.logical_core_node_map
        numa_ids = []
        for core in core_list:
            numa_id = cores_numa_map[core]
            if not numa_id in numa_ids:
                numa_ids.append(numa_id)
        if len(numa_ids) > 1:
            logger.warning("Numa Aware: cores:{} on different NUMA nodes:{}".format(str(core_list), str(numa_ids)))
        if len(numa_ids) == 0:
            logger.error("invalid number of NUMA nodes; please make sure numa_ids >= 1")
            exit(-1)
        return numa_ids

class Launcher():
    r"""
     Base class for launcher
    """
    def __init__(self):
        self.cpuinfo = CPUinfo()

    def launch(self, args):
        pass

    def is_numactl_available(self):
        numactl_available = False
        cmd = ["numactl", "-C", "0", "-m", "0", "ls"]
        r = subprocess.run(cmd, env=os.environ, stdout=subprocess.DEVNULL)
        if r.returncode == 0:
            numactl_available = True
        return numactl_available

    def logger_env(self, env_name=""):
        if env_name in os.environ:
            logger.info("{}={}".format(env_name, os.environ[env_name]))

    def set_env(self, env_name, env_value=None):
        if not env_value:
            logger.warning("{} is None".format(env_name))
        if env_name not in os.environ:
            os.environ[env_name] = env_value
        elif os.environ[env_name] != env_value:
            logger.warning("{} in environment variable is {} while the value you set is {}".format(env_name, os.environ[env_name], env_value))
            os.environ[env_name] = env_value
        self.logger_env(env_name)


class MultiInstanceLauncher(Launcher):
    r"""
     Launcher for single instance and multi-instance
     """
    def launch(self, args):
        processes = []
        cores = []
        set_kmp_affinity = True
        enable_taskset = False
        if args.core_list:  # user specify what cores will be used by params
            for core_list_elem in args.core_list.split(","):
                spec_core = core_list_elem.strip()
                if spec_core.isdigit():
                    cores.append(int(spec_core))
                else:
                    core_range = [int(x.strip()) for x in spec_core.split("-")]
                    assert len(core_range) == 2, "Invalid core_list argument format"
                    beg, end = core_range
                    if beg > end:
                        beg, end = end, beg
                    cores.extend(list(range(beg, end + 1)))
            cores = list(set(cores))
            valid_cores = self.cpuinfo.get_all_physical_cores() + self.cpuinfo.get_all_logical_cores()
            for c in cores:
                assert c in valid_cores, "Invalid core ID {} in core_list argument".format(c)

            if args.ncore_per_instance == -1:
                logger.error("please specify the '--ncore_per_instance' if you have pass the --core_list params")
                exit(-1)
            elif args.ninstances > 1 and args.ncore_per_instance * args.ninstances < len(cores):
                logger.warning("only first {} cores will be used, but you specify {} cores in core_list".format(args.ncore_per_instance * args.ninstances, len(cores)))
            else:
                args.ninstances = len(cores) // args.ncore_per_instance

        else:
            if os.environ.get('OMP_NUM_THREADS') is not None:
                if args.node_id != -1:
                    physical_cores_number = len(self.cpuinfo.get_node_physical_cores(args.node_id))
                else:
                    physical_cores_number = len(self.cpuinfo.get_all_physical_cores())

                if int(os.environ.get('OMP_NUM_THREADS')) > physical_cores_number:
                    logger.warning("there are {} physical cores but you specify OMP_NUM_THREADS equals to {} ; please set OMP_NUM_THREADS <= physical cores or add argument --use_logical_core to use logical core to meet your setting threads".format(physical_cores_number, int(os.environ.get('OMP_NUM_THREADS')) ))
            if args.use_logical_core:
                if args.node_id != -1:
                    cores = self.cpuinfo.get_node_logical_cores(args.node_id)
                else:
                    cores = self.cpuinfo.get_all_logical_cores()
                    # When using all cores on all nodes, including logical cores, setting KMP_AFFINITY disables logical cores. Thus, KMP_AFFINITY should not be set.
                    set_kmp_affinity = False
            else:
                if args.node_id != -1:
                    cores = self.cpuinfo.get_node_physical_cores(args.node_id)
                else:
                    cores = self.cpuinfo.get_all_physical_cores()
            if not args.multi_instance and args.ninstances == -1 and args.ncore_per_instance == -1:
                args.ninstances = 1
                args.ncore_per_instance = len(cores)
            elif args.multi_instance and args.ninstances == -1 and args.ncore_per_instance == -1:
                args.throughput_mode = True
            elif args.ncore_per_instance == -1 and args.ninstances != -1:
                if args.ninstances > len(cores):
                    logger.error("there are {} total cores but you specify {} ninstances; please make sure ninstances <= total_cores)".format(len(cores), args.ninstances))
                    exit(-1)
                else:
                    args.ncore_per_instance = len(cores) // args.ninstances
            elif args.ncore_per_instance != -1 and args.ninstances == -1:
                if not args.skip_cross_node_cores:
                    args.ninstances = len(cores) // args.ncore_per_instance
                else:
                    ncore_per_node = len(self.cpuinfo.node_physical_cores[0])
                    num_leftover_cores = ncore_per_node % args.ncore_per_instance
                    if args.ncore_per_instance > ncore_per_node:
                        # too many ncore_per_instance to skip cross-node cores
                        logger.warning("there are {} core(s) per socket, but you specify {} ncore_per_instance and skip_cross_node_cores. Please make sure --ncore_per_instance < core(s) per socket".format(ncore_per_node, args.ncore_per_instance))
                        exit(-1)
                    elif num_leftover_cores == 0:
                        # aren't any cross-node cores
                        logger.info('--skip_cross_node_cores is set, but there are no cross-node cores.')
                        args.ninstances = len(cores) // args.ncore_per_instance
                    else:
                        # skip cross-node cores
                        if args.ninstances != -1:
                            logger.warning('--skip_cross_node_cores is exclusive to --ninstances. --ninstances won\'t take effect even if it is set explicitly.')

                        i = 1
                        leftover_cores = set()
                        while ncore_per_node*i <= len(cores):
                            leftover_cores.update(cores[ncore_per_node*i-num_leftover_cores : ncore_per_node*i])
                            i += 1
                        cores = list(set(cores) - leftover_cores)
                        assert len(cores) % args.ncore_per_instance == 0
                        args.ninstances = len(cores) // args.ncore_per_instance
            else:
                if args.ninstances * args.ncore_per_instance > len(cores):
                    logger.error("Please make sure ninstances * ncore_per_instance <= total_cores")
                    exit(-1)
            if args.latency_mode:
                logger.warning('--latency_mode is exclusive to --ninstances, --ncore_per_instance, --node_id and --use_logical_core. They won\'t take effect even if they are set explicitly.')
                args.ncore_per_instance = 4
                cores = self.cpuinfo.get_all_physical_cores()
                args.ninstances = len(cores) // args.ncore_per_instance

            if args.throughput_mode:
                logger.warning('--throughput_mode is exclusive to --ninstances, --ncore_per_instance, --node_id and --use_logical_core. They won\'t take effect even if they are set explicitly.')
                args.ninstances = self.cpuinfo.node_nums()
                cores = self.cpuinfo.get_all_physical_cores()
                args.ncore_per_instance = len(cores) // args.ninstances

        if args.ninstances > 1 and args.instance_idx != -1:
            logger.info("assigning {} cores for instance {}".format(args.ncore_per_instance, args.instance_idx))

        if not args.disable_numactl:
            numactl_available = self.is_numactl_available()
            if not numactl_available:
                if not args.disable_taskset:
                    logger.warning("Core binding with numactl is not available. Disabling numactl and using taskset instead. This may affect performance in multi-socket system; please use numactl if memory binding is needed.")
                    args.disable_numactl = True
                    enable_taskset = True
                else:
                    logger.warning("Core binding with numactl is not available, and --disable_taskset is set. Please unset --disable_taskset to use taskset insetad of numactl.")
                    exit(-1)

        if not args.disable_taskset:
            enable_taskset = True

        os.environ["LAUNCH_CMD"] = "#"

        for i in range(args.ninstances):
            cmd = []
            cur_process_cores = ""
            if not args.disable_numactl or enable_taskset:
                if not args.disable_numactl:
                    cmd = ["numactl"]
                elif enable_taskset:
                    cmd = ["taskset"]

                cores = sorted(cores)
                if args.instance_idx == -1:  # sequentially assign ncores_per_instance to ninstances
                    core_list = cores[i * args.ncore_per_instance: (
                        i + 1) * args.ncore_per_instance]
                else:  # assign ncores_per_instance from instance_idx
                    core_list = cores[args.instance_idx * args.ncore_per_instance: (
                        args.instance_idx + 1) * args.ncore_per_instance]

                core_ranges = []
                for core in core_list:
                    if len(core_ranges) == 0:
                        range_elem = {'start': core, 'end': core}
                        core_ranges.append(range_elem)
                    else:
                        if core - core_ranges[-1]['end'] == 1:
                            core_ranges[-1]['end'] = core
                        else:
                            range_elem = {'start': core, 'end': core}
                            core_ranges.append(range_elem)
                for r in core_ranges:
                    cur_process_cores = cur_process_cores + "{}-{},".format(r['start'], r['end'])
                cur_process_cores = cur_process_cores[:-1]

                if not args.disable_numactl:
                    numa_params = "-C {} ".format(cur_process_cores)
                    numa_params += "-m {}".format(",".join(
                        [str(numa_id) for numa_id in self.cpuinfo.numa_aware_check(core_list)]))
                    cmd.extend(numa_params.split())
                elif enable_taskset:
                    taskset_params = "-c {}".format(cur_process_cores)
                    cmd.extend(taskset_params.split())

            with_python = not args.no_python
            if with_python:
                cmd.append(sys.executable)
                cmd.append("-u")
            if args.module:
                cmd.append("-m")
            cmd.append(args.program)
            log_name = args.log_file_prefix + "_instance_{}_cores_".format(i) + cur_process_cores.replace(',', '_') + ".log"
            log_name = os.path.join(args.log_path, log_name)
            cmd.extend(args.program_args)
            os.environ["LAUNCH_CMD"] += " ".join(cmd) + ",#"
            cmd_s = " ".join(cmd)
            if args.log_path:
                cmd_s = "{} 2>&1 | tee {}".format(cmd_s, log_name)
            logger.info(cmd_s)
            if not args.disable_numactl:
                process = subprocess.Popen(cmd_s, env=os.environ, shell=True)
            elif enable_taskset:
                process = subprocess.Popen(cmd, env=os.environ)
            processes.append(process)

            if args.instance_idx != -1: # launches single instance, instance_idx, only
                break

        os.environ["LAUNCH_CMD"] = os.environ["LAUNCH_CMD"][:-2]
        try:
            for process in processes:
                process.wait()
                if process.returncode != 0:
                    raise subprocess.CalledProcessError(returncode=process.returncode, cmd=cmd_s)
        finally:
            pass


def add_multi_instance_params(parser):

    group = parser.add_argument_group("Multi-instance Parameters")
    # multi-instance control
    group.add_argument("--ncore_per_instance", metavar='\b', default=-1, type=int,
                       help="Cores per instance")
    group.add_argument("--skip_cross_node_cores", action='store_true', default=False,
                       help="If specified --ncore_per_instance, skips cross-node cores.")
    group.add_argument("--ninstances", metavar='\b', default=-1, type=int,
                       help="For multi-instance, you should give the cores number you used for per instance.")
    group.add_argument("--instance_idx", metavar='\b', default="-1", type=int,
                       help="Specify instance index to assign ncores_per_instance for instance_idx; otherwise ncore_per_instance will be assigned sequentially to ninstances. Please refer to https://github.com/intel/intel-extension-for-pytorch/blob/master/docs/tutorials/performance_tuning/launch_script.md")
    group.add_argument("--latency_mode", action='store_true', default=False,
                       help="By detault 4 core per instance and use all physical cores")
    group.add_argument("--throughput_mode", action='store_true', default=False,
                       help="By default one instance per node and use all physical cores")
    group.add_argument("--node_id", metavar='\b', default=-1, type=int,
                       help="node id for multi-instance, by default all nodes will be used")
    group.add_argument("--use_logical_core", action='store_true', default=False,
                       help="Whether only use physical cores")
    group.add_argument("--disable_numactl", action='store_true', default=False,
                       help="Disable numactl")
    group.add_argument("--disable_taskset", action='store_true', default=False,
                       help="Disable taskset")
    group.add_argument("--core_list", metavar='\b', default=None, type=str,
                       help="Specify the core list as 'core_id, core_id, ...' or 'core_id-core_id, ...', otherwise, all the cores will be used.")
    group.add_argument("--benchmark", action='store_true', default=False,
                   help="Enable benchmark config. JeMalloc's MALLOC_CONF has been tuned for low latency. Recommend to use this for benchmarking purpose; for other use cases, this MALLOC_CONF may cause Out-of-Memory crash.")
    group.add_argument("--log_path", metavar='\b', default="", type=str,
                       help="The log file directory. Default path is '', which means disable logging to files.")
    group.add_argument("--log_file_prefix", metavar='\b', default="run", type=str,
                       help="log file prefix")

def parse_args():
    """
    Helper function parsing the command line options
    @retval ArgumentParser
    """
    parser = ArgumentParser(description="This is a script for launching TensorFlow training and inference on Intel Xeon CPU ",
                                        formatter_class=RawTextHelpFormatter)

    parser.add_argument("--multi_instance", action='store_true', default=False,
                        help="Enable multi-instance, by default one instance per node")

    parser.add_argument('--distributed', action='store_true', default=False,
                        help='Enable distributed training.')
    parser.add_argument("-m", "--module", default=False, action="store_true",
                        help="Changes each process to interpret the launch script "
                             "as a python module, executing with the same behavior as"
                             "'python -m'.")

    parser.add_argument("--no_python", default=False, action="store_true",
                        help="Do not prepend the --program script with \"python\" - just exec "
                             "it directly. Useful when the script is not a Python script.")

    add_multi_instance_params(parser)

    # positional
    parser.add_argument("program", type=str,
                        help="The full path to the proram/script to be launched. "
                             "followed by all the arguments for the script")

    # rest from the training program
    parser.add_argument('program_args', nargs=REMAINDER)
    return parser.parse_args()

def main():

    env_before = set(os.environ.keys())
    if platform.system() == "Windows":
        raise RuntimeError("Windows platform is not supported!!!")

    args = parse_args()
    if args.log_path:
        path = os.path.dirname(args.log_path if args.log_path.endswith('/') else args.log_path + '/')
        if not os.path.exists(path):
            os.makedirs(path)
        args.log_path = path

        args.log_file_prefix = '{}_{}'.format(args.log_file_prefix, datetime.now().strftime("%Y%m%d%H%M%S"))
        fileHandler = logging.FileHandler("{0}/{1}_instances.log".format(args.log_path, args.log_file_prefix))
        logFormatter = logging.Formatter(format_str)
        fileHandler.setFormatter(logFormatter)
        logger.addHandler(fileHandler)

    if args.latency_mode and args.throughput_mode:
        raise RuntimeError("Either args.latency_mode or args.throughput_mode should be set")

    if not args.no_python and not args.program.endswith(".py"):
        logger.error("For non Python script, you should use '--no_python' parameter.")
        exit()

    launcher = MultiInstanceLauncher()

    launcher.launch(args)
    for x in sorted(set(os.environ.keys()) - env_before):
        logger.debug('{0}={1}'.format(x, os.environ[x]))

if __name__ == "__main__":
    main()
