# rocksdb-iaa

ARG OS_VER=8.5
ARG OS_IMAGE=rockylinux
ARG RELEASE
FROM rocksdb-iaa-base${RELEASE} as build


# rebuild image with support Calgary
ARG ROCKSDB_REPO=https://github.com/facebook/rocksdb.git
ARG ROCKSDB_VER=https://github.com/facebook/rocksdb/pull/6717
ARG ROCKSDB_IAA_PLUGIN_VER=v0.3.0
ARG ROCKSDB_IAA_PLUGIN_REPO=https://github.com/intel/iaa-plugin-rocksdb.git

RUN git clone https://github.com/facebook/rocksdb.git  rocksdb_calgary && \
    cd rocksdb_calgary && \
    git config --global user.email "you@example.com" && \
    git fetch origin pull/10395/head && \
    git checkout -b file_data FETCH_HEAD && \
    git fetch origin pull/6717/head && \
    git checkout -b pluggable_compression FETCH_HEAD && \
    git checkout -b pluggable_compression_file_data && \
    git cherry-pick file_data && \
    git clone -b ${ROCKSDB_IAA_PLUGIN_VER} ${ROCKSDB_IAA_PLUGIN_REPO} plugin/iaa_compressor && \
    EXTRA_CXXFLAGS="-I/qpl/include -I/usr/local/include" EXTRA_LDFLAGS="-L/qpl/lib64 -L/usr/local/lib -L/usr/lib" ROCKSDB_CXX_STANDARD="c++17" DISABLE_WARNING_AS_ERROR=1 ROCKSDB_PLUGINS="iaa_compressor" make -j7 release


FROM ${OS_IMAGE}:${OS_VER}

RUN yum update -y && \
    yum install pciutils numactl wget unzip lz4-devel -y && \
    yum install snappy-devel --enablerepo=powertools sysstat bc -y

COPY  --from=build /qpl /qpl

RUN rm -rf /usr/lib64/libzstd*
COPY --from=build /usr/local/lib/libzstd* /usr/lib64/

COPY  --from=build /rocksdb_calgary/db_bench /rocksdb/rocksdb/db_bench
COPY  --from=build /usr/bin/accel-config /usr/bin/accel-config
COPY  --from=build /usr/bin/gflags_completions.sh /usr/bin/gflags_completions.sh

COPY --from=build /usr/lib/libgflags.so /usr/lib/libgflags.so
COPY --from=build /usr/lib/libgflags.so.2.2 /usr/lib/libgflags.so.2.2
COPY --from=build /usr/lib/libgflags.so.2.2.2 /usr/lib/libgflags.so.2.2.2
COPY --from=build /usr/lib/libgflags_nothreads.so /usr/lib/libgflags_nothreads.so
COPY --from=build /usr/lib/libgflags_nothreads.so.2.2 /usr/lib/libgflags_nothreads.so.2.2
COPY --from=build /usr/lib/libgflags_nothreads.so.2.2.2 /usr/lib/libgflags_nothreads.so.2.2.2

COPY --from=build /usr/lib64/libaccel-config.la /usr/lib64/libaccel-config.la
COPY --from=build /usr/lib64/libaccel-config.so /usr/lib64/libaccel-config.so
COPY --from=build /usr/lib64/libaccel-config.so.1 /usr/lib64/libaccel-config.so.1
COPY --from=build /usr/lib64/libaccel-config.so.1.0.0 /usr/lib64/libaccel-config.so.1.0.0

# download Calgary
ARG CALGARY_REPO=http://www.data-compression.info/files/corpora/calgarycorpus.zip
ARG CALGARY_VER=latest
RUN wget ${CALGARY_REPO} && \
    unzip calgarycorpus.zip -d calgarycorpus && \
    cd calgarycorpus && \
    for i in `ls ./`; do cat $i >> /rocksdb/standard_calgary_corpus; done;

# copy test script
COPY script/configure_iaa_user /rocksdb/scripts/configure_iaa_user
COPY script/run_test.sh /run_test.sh
COPY script/db_bench_test_scaling_ALL.sh /db_bench_test_scaling_ALL.sh


RUN chmod +x /rocksdb/scripts/configure_iaa_user  && \
    chmod +x /run_test.sh && \
    chmod +x /db_bench_test_scaling_ALL.sh


WORKDIR /
RUN  mkfifo /export-logs
CMD (bash run_test.sh ; echo $? > status) 2>&1 | tee output.logs && \
    tar cf /export-logs status output.logs && \
    sleep infinity
