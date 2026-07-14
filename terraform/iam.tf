# SSM registration gives a break-glass path to the instances if the SSH
# security group rule ever locks the operator out mid-hardening.

resource "aws_iam_role" "target" {
  name = "${var.name_prefix}-target-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.target.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "target" {
  name = "${var.name_prefix}-target-profile"
  role = aws_iam_role.target.name
}
