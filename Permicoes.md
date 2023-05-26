# Permições

<aside>
💡 Dica: cuidado com as chaves abertas e fechadas, durante a explicação algumas chaves podem ter seu par em outro segmento de codigo.

</aside>

Pelo modelo de permições da AWS, é necessario criarmos uma serie de *roles,* que funcionam como cargos, e atribuir *******policies,******* ou autorizações, para cada ação em cada tipo de instancia.

Para orgainzar melhor, foi criado um role para cada instancia, e uma serie de policies a partir do alvo de cada ação, e por fim foram atribuidas essas politicas para os roles cabiveis. Mais detalhes [sobre roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ou [sobre policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) estão disponivies na documentação da AWS.

## *Roles*

### EC2

A intancia EC2 recebe um tratamento um pouco diferente, pois alem do seu role, também é preciso a criação de um *security group* e um *instance profile,* o primeiro responsavel pelas definiçoes de entrada e saida de rede da instancia, e o segundo, que apenas linka o role com a instancia propriamente.

```makefile
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
```

### O Bucket

Uma vez que os roles são baseados nos agente e as policies dizem respeito aos alvos de ações entre intancias diferentes, não é necessario criar um role para o S3 Bucket, uma vez que ele é apena alvo, nunca agente na infraestrutura em questão.

### O Pipeline

```makefile
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
```

### O Build

```makefile
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
```

### O Deploy

```makefile
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
    }
  ]
}
EOF
}
```

## Policies

### S3 Bucket

A *policy* do S3 defini quais acessos podem ser feitos dentro da pasta, como read e write, mas é importante notar que a tag  *Resource* limita esse acesso a um unico objeto, nese caso, definido pelo criado no projeto, impedindo que outros projetos e instancias leiam, ou ainda, alterem, a pasta utilizada pelo pipeline

```makefile
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
```

### Build

A política permite informar resultados de sucesso ou falha de execuções no CodePipeline e realizar ações específicas no CodeBuild, como buscar e iniciar builds.

```makefile
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
```

### Deploy

O deploy deve acessar artefatos no S3, realizar escritas e execuções relacionadas à EC2. A 

```makefile
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
```

### Pipeline

A politica do pipelie possui uma permição para cada uma de suas fases, primeiramente autorizando a conexção com o github, seguido do acesso ao CodeBuild e CodeDeploy

```makefile
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
```

### ECR

A politica concede permissões para realizar ações no Amazon Elastic Container Registry (ECR), host do container utilizado pelo CodeBuild. 

```makefile
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
```

## Attachment

Por fim, precisamos apenas linkar as devidas policies aos roles que as utilizam, infelizmente por esse metudo cada par politica-papel tem que receber uma criação indivudal, mas torna mais claro quais atribuições foram feitas.

```
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
```