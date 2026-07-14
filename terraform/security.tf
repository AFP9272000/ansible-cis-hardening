resource "aws_security_group" "targets" {
  name        = "${var.name_prefix}-targets"
  description = "SSH from the operator or CI runner only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound (apt, SSM, SCAP content downloads)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-targets-sg"
  }
}
