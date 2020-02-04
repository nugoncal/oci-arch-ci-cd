## DATASOURCE
# Init Script Files
data "template_file" "setup_jenkins" {
  template = "${file("${path.module}/scripts/setup.sh")}"

  vars = {
    jenkins_version  = "${var.jenkins_version}"
    jenkins_password = "${var.jenkins_password}"
    http_port        = "${var.http_port}"
    plugins          = "${join(" ", var.plugins)}"
  }
}

data "template_file" "init_jenkins" {
  template = "${file("${path.module}/scripts/default-user.groovy")}"

  vars = {
    jenkins_password = "${var.jenkins_password}"
  }
}

## JENKINS MASTER INSTANCE
resource "oci_core_instance" "TFJenkinsMaster" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain - 2],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  shape               = "${var.instance_shape}"
  display_name        = "${var.master_display_name}"

  create_vnic_details {
    subnet_id        = "${var.subnet_id}"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }

  source_details {
    source_id   = "${var.image_ocid}"
    source_type = "image"
  }

  provisioner "file" {
    connection {
      host        = "${oci_core_instance.TFJenkinsMaster.public_ip}"
      agent       = false
      timeout     = "5m"
      user        = "${var.instance_user}"
      private_key = "${var.ssh_private_key}"
    }

    content     = "${data.template_file.setup_jenkins.rendered}"
    destination = "~/setup.sh"
  }

  provisioner "file" {
    connection {
      host        = "${oci_core_instance.TFJenkinsMaster.public_ip}"
      agent       = false
      timeout     = "5m"
      user        = "${var.instance_user}"
      private_key = "${var.ssh_private_key}"
    }

    content     = "${data.template_file.init_jenkins.rendered}"
    destination = "~/default-user.groovy"
  }

  provisioner "remote-exec" {
    connection {
      host        = "${oci_core_instance.TFJenkinsMaster.public_ip}"
      agent       = false
      timeout     = "5m"
      user        = "${var.instance_user}"
      private_key = "${var.ssh_private_key}"
    }

    inline = [
      "chmod +x ~/setup.sh",
      "sudo ~/setup.sh",
    ]
  }

  timeouts {
    create = "10m"
  }
}
