data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.sh")

  vars = {
    cluster_name            = "${var.name}-cluster"
    dag_s3_bucket           = var.dag_s3_bucket
    dag_s3_key              = var.dag_s3_key
    rclone_secret_key_id    = var.rclone_secret_key_id
    rclone_secret_key       = var.rclone_secret_key
    region                  = var.region
    custom_user_data        = var.custom_user_data
    airflow_home            = var.airflow_home
  }
}

resource "aws_launch_configuration" "ecs" {
  name_prefix          = "lc-${var.name}"
  image_id             = var.ecs_ami_id
  instance_type        = var.ecs_instance_type
  user_data            = data.template_file.user_data.rendered
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.airflow-task-definition-execution-profile.name

  ebs_block_device {  # TODO(ilya_isakov): do we need this ebs?
    device_name           = var.ebs_block_device_name
    volume_size           = var.ebs_block_device_volume_size
    volume_type           = var.ebs_block_device_volume_type
    delete_on_termination = var.ebs_block_device_delete_on_termination
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                 = "autoscaling-${var.name}"
  launch_configuration = aws_launch_configuration.ecs.name
  vpc_zone_identifier  = var.private_subnet_ids
  min_size             = 2
  max_size             = 2

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "AppService"
    value               = "Airflow"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    iterator = tag
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

}

resource "aws_cloudwatch_log_group" "ecs_cloudwatch_logs" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.cloudwatch_retention
  tags              = var.tags
}