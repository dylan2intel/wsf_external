output "instances" {
  value = {
    for i, instance in var.spot_instance?aws_spot_instance_request.default:aws_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: local.os_image_user[local.instances[i].os_type]
        instance_type: instance.instance_type,
    }
  }
}

output "terraform_replace" {
  value = {
    command = join(" ",[
      for k,v in local.instances :
        var.spot_instance?"-replace=aws_spot_instance_request.default[${k}]":"-replace=aws_instance.default[${k}]"
        if v.cpu_model_regex!=null?(replace(data.external.cpu_model[k].result.cpu_model,startswith(v.cpu_model_regex,"/")?v.cpu_model_regex:"/^.*${v.cpu_model_regex}.*$/", "")!=""):false
    ])
    cpu_model = {
      for k,v in local.instances :
        k => data.external.cpu_model[k].result.cpu_model
        if v.cpu_model_regex!=null
    }
  }
}
