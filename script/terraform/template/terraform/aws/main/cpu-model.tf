
data "external" "cpu_model" {
  for_each = {
    for k,v in local.instances : k => v
      if v.cpu_model_regex != null
  }

  program = [
    "timeout",
    var.cpu_model_timeout,
    "${path.module}/templates/get-cpu-model.sh",
    "-i",
    "${path.root}/${var.ssh_pri_key_file}",
    "${local.os_image_user[each.value.os_type]}@${var.spot_instance?aws_spot_instance_request.default[each.key].public_ip:aws_instance.default[each.key].public_ip}"
  ]
}
