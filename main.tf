provider "aws" {
  region = "us-east-1"  # Update with your desired region
}
############################################################################################################################

resource "aws_security_group" "sec_grp" {
  name        = "example-sg"
  description = "Example security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_iam_role" "ec2_role" {
  name = "example-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
# IAM Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "example-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "codepipeline_role" {
  name = "example-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}



resource "aws_iam_role" "codebuild_role" {
  name = "example-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "codedeploy_role" {
  name = "example-codedeploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}



resource "aws_iam_policy" "codebuild_policy" {
  name        = "example-codebuild-policy"
  description = "Permissions for CodePipeline and CodeBuild"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCodePipelineAccess",
      "Effect": "Allow",
      "Action": [
        "codepipeline:PutJobSuccessResult",
        "codepipeline:PutJobFailureResult"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowCodeBuildAccess",
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "arn:aws:codebuild:us-east-1:920358117159:project/example-codebuild-project"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "s3_policy" {
  name        = "example-codepipeline-s3-policy"
  description = "Permissions for CodePipeline to access S3 artifacts bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "${aws_s3_bucket.artifacts_bucket.arn}/*"
    },
    {
      "Sid": "AllowListBuckets",
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "example-cloudwatch-policy"
  description = "Permissions for CodeBuild to create CloudWatch Logs log streams"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codedeploy_policy" {
  name        = "example-codedeploy-policy"
  description = "Permissions for CodeDeploy to access artifacts"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCodeDeployAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "${aws_s3_bucket.artifacts_bucket.arn}/*"
    },
    {
      "Sid": "AllowCodeDeployDeployments",
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplicationRevision",
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:GetDeploymentGroup",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentTarget",
        "codedeploy:GetOnPremisesInstance",
        "codedeploy:ListDeploymentTargets",
        "codedeploy:ListDeployments",
        "codedeploy:ListDeploymentConfigs",
        "codedeploy:ListApplications",
        "codedeploy:ListDeploymentGroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowEC2Operations",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:RunInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = "example-codepipeline-policy"
  description = "Permissions for CodePipeline"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCodeStarConnectionsAccess",
      "Effect": "Allow",
      "Action": "codestar-connections:UseConnection",
      "Resource": "arn:aws:codestar-connections:us-east-1:920358117159:connection/fee01a51-f2c6-4e2f-b200-4eeeb39ede94"
    },
    {
      "Sid": "AllowCodeBuildAccess",
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowCodeBuildProjectAccess",
      "Effect": "Allow",
      "Action": "codestar-connections:UseConnection",
      "Resource": "arn:aws:codebuild:us-east-1:920358117159:project/example-codebuild-project"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecr_policy" {
  name        = "example-ecr-policy"
  description = "Policy to allow ECR actions for example-codebuild-role"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "pipeline_s3_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "pipeline_deploy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codedeploy_policy.arn
}
resource "aws_iam_role_policy_attachment" "pipeline_build_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

resource "aws_iam_role_policy_attachment" "build_watch_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

resource "aws_iam_role_policy_attachment" "build_s3_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

####
resource "aws_iam_role_policy_attachment" "deploy_s3_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}


resource "aws_iam_role_policy_attachment" "deploy_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = aws_iam_policy.codedeploy_policy.arn
}

resource "aws_iam_role_policy_attachment" "pipeline_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_iam_role_policy_attachment" "build_ecr_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.ecr_policy.arn
}

resource "aws_iam_role_policy_attachment" "c2_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" # Example policy with full EC2 access
}

resource "aws_iam_role_policy_attachment" "deploy_ec2_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" # Example policy with full EC2 access
}
resource "aws_iam_role_policy_attachment" "ec2_s3_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}
3

#BUCKET
resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = "example-codepipeline-artifacts"
  force_destroy = true
}

#EC2
resource "aws_instance" "intancia_ec2" {
  ami           = "ami-016048c3d1d2a393b"  # Replace with the desired AMI ID
  instance_type = "t2.micro"                # Replace with the desired instance type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  #atribui o role ao ec2
  

  vpc_security_group_ids = [aws_security_group.sec_grp.id]

  tags = {
    Name = "instance_pipeline"
  }
}


#BUILD
resource "aws_codebuild_project" "build_proj" {
  name          = "codebuild-project"
  description   = "Example CodeBuild project"
  build_timeout = 300
  service_role      = aws_iam_role.codebuild_role.arn


  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml"  # Replace with the path to your buildspec file
    report_build_status = true
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

artifacts {
    type     = "CODEPIPELINE"
    name     = "example-artifacts"  # Replace with your desired artifact name
    namespace_type = "NONE"
  }

}




resource "aws_codedeploy_app" "deploy_app" {
  name = "deployapplication"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "deploy_group" {
  app_name               = aws_codedeploy_app.deploy_app.name
  deployment_group_name  = "example-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"  # Choose the deployment configuration that suits your needs
  
  deployment_style {
    deployment_type = "IN_PLACE"
  }
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = aws_instance.intancia_ec2.tags.Name
    }
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

}


#PIPELINE
resource "aws_codepipeline" "Pipeline" {
  name     = "codepipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts_bucket.bucket
    type     = "S3"
  }

stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:us-east-1:920358117159:connection/fee01a51-f2c6-4e2f-b200-4eeeb39ede94"
        FullRepositoryId = "Antonioarf/micro-api" ############################################################################
        BranchName       = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["build"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_proj.name
      }
    }
  }

 stage {
    name = "Deploy"

    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts  = ["build"]
      configuration = {
        ApplicationName    = aws_codedeploy_app.deploy_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.deploy_group.deployment_group_name
      }
    }
  }
}



