# Dependencias

<aside>
💡 Dica: cuidado com as chaves abertas e fechadas, durante a explicação algumas chaves podem ter seu par em outro segmento de codigo.

</aside>

Para essa implementação, foram necessarias as seguintes instancias alem do Pipeline.

- [CodeBuild](https://aws.amazon.com/codebuild/): container responsavel pelo build e testes, garantindo a integridade do deploy.
- [CodeDeploy](https://aws.amazon.com/codedeploy/): mecanismo de introdução e execução do build para dentro da instancia target.
- [EC2](https://aws.amazon.com/ec2/): instancia criada para simular o ambiente de produção onde o pipeline deve atuar.
- [S3 Bucket](https://aws.amazon.com/s3/): armazenamento dos arquivos temporarios entre as fases.

## CodeBuild

A intancia do codebuid é contituida por tres componentes principais, ****source, environment**** e ****artifacts.**** O source é responsavel por contextualizar o build em relação ao pipeline, e não à uma chamada independente, por exemplo. O atributo ***********buildspec*********** indica qual arquivo .yml deve ser executado com as instruções a serem seguidas.

```makefile
resource "aws_codebuild_project" "build_proj" {
  name          = "codebuild-project"
  description   = "Example CodeBuild project"
  build_timeout = 300
  service_role      = aws_iam_role.codebuild_role.arn

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml" #colocar o path se não estiver na raiz do diretorio
}
```

### BuildSpec.yml

Define o conjunto de instruções e comandos necessários para realizar as ações desejadas durante o processo de construção, como a compilação, execução de testes, criação de artefatos etc.. O modelo abaixo monstra uma estrutura basica para esse arquivo, com tres fases de execução e um comando de artefatos para definir o que deve ser salvo no Bucket.

```makefile
version: 0.2

phases:
  build:
    commands:
      - echo "Iniciando o processo de construção"
      - npm install  # exemplo de comando para instalar dependências
      - npm run build  # exemplo de comando para construir o aplicativo

  test:
    commands:
      - echo "Iniciando os testes"
      - npm run test  # exemplo de comando para executar os testes automatizados

  deploy:
    commands:
      - echo "Iniciando a implantação"
      - aws s3 sync ./dist s3://meu-bucket/  # exemplo de comando para implantar em um bucket do Amazon S3
      - aws cloudfront create-invalidation --distribution-id ABCDEFGHIJKLMN --paths "/*"  # exemplo de comando para invalidar o cache de uma distribuição do Amazon CloudFront

artifacts:
  files:
    - dist/**/*
```

Em referência ao terraform, o próximo passo é definir o ambiente de execução do build, nesse caso, como um container linux, definido pela imagem, que se refere ao ubuntu 20.4, mesmo ambiente utilizado na instancia EC2. 

```makefile
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

artifacts {
    type     = "CODEPIPELINE"
    name     = "example-artifacts"
    namespace_type = "NONE"
  }

}
```

## CodeDeploy

Diferentemente do CodeBuild, o CodeDeploy é formado por duas instancias separadas, uma aplicação, e um grupo de deploy, que precisam ser criados separadamente.

Para a criação da applicação, basta o codigo abaixo, uma vez que a maior parte dos comandos são definidos pelo *deployment group.*

```makefile
resource "aws_codedeploy_app" "deploy_app" {
  name = "deployapplication"
  compute_platform = "Server"
}
```

O deployment group é assim nomedao por orquestrar o deploy para varias instancias simultaneamente, mas seguindo um comando e monitoramento central. Por isso, é definido o *deployment_config_name* como *OneATime*, para instruir como organizar varios deploy pelo mesmo grupo. 

Para selecionar uma ou mais intancias de target, é utilizado o *ec2_tag_set. N*esse caso, configura-se para filtrar pelo nome, buscando pelo atributo da instancia definida no mesmo arquvio. Outra variavel a ser definida é o cenario de rollback, acionado caso o deploy não seja bem sucedido. 

<aside>
💡 No caso de deploy para varias instancias, pode ser definido como for interessante o que configura uma falha ou sucesso para o gropo como um todo

</aside>

```makefile
resource "aws_codedeploy_deployment_group" "deploy_group" {
  app_name               = aws_codedeploy_app.deploy_app.name
  deployment_group_name  = "example-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"  
  
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
```

Tal qual o Codebuild segue as intruções do arquivo buildspec.yml, o CodeDeploy, apesar de não estar explicitado pelo codigo terraform, segue o arquivo appspec.yml, que especifica os *hooks* da implantação. 

Cada gancho deve ser associado a um script específico que será executado durante a implementação. Esses scripts podem conter ações como; parar o serviço em execução, fazer backup de dados, instalar dependências, configurar o ambiente, iniciar o serviço, entre outras tarefas.

```makefile
version: 0.0
os: linux

resources:
  - TargetService:
      Type: AWS::EC2::Instance
      Properties:
        InstanceName: my-ec2-instance
        AutoScalingGroup: my-auto-scaling-group

hooks:
  ApplicationStop:
    - location: scripts/stop.sh
      timeout: 300
  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 300
  AfterInstall:
    - location: scripts/after_install.sh
      timeout: 300
  ApplicationStart:
    - location: scripts/start.sh
      timeout: 300

permissions:
  - object: /
    pattern: "**"
    owner: ec2-user
    group: ec2-user
```

## EC2

Por se tratar de um tutorial, tambem cria-se uma instancia EC2 para servir como target para o deploy, mas normalmente o target ja deve existir como parte de outra infraestrutura a ser atualizada pelo pipeline. Define-se que seria utilizada uma imagem de ubuntu 20.04, influenciando também no tipo de container definido no CodeBuild, e a unica tag atribuida foi o nome, tal como descrito no filtro do deployment group acima.

```makefile
resource "aws_instance" "intancia_ec2" {
  ami           = "ami-016048c3d1d2a393b"  
  instance_type = "t2.micro"                
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  

  vpc_security_group_ids = [aws_security_group.sec_grp.id]

  tags = {
    Name = "instance_pipeline"
  }
}
```

A imagem utilizada acima é customizada e publica na região us-east-1 da aws, pois para  funcionamento do pipeline, é necessario que a instancia possua já instalada o CodeDeploy Agent, disponibilizado pela AWS para possibilitar a fase de deploy. 

Caso seja interessente a utilização de outra imagem, o software necessario pode ser baixado para Ubuntu com os comandos abaixo, ainda assim, outras formas de download e detalhes estão disponiveis [neste link](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install.html)

```makefile
sudo apt-get update
sudo apt-get install -y ruby wget
cd /home/ubuntu
wget [https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install](https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install)
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent status
```

## Bucket S3

O repositorio S3 foi criado para armazenar, compartilhar e disponibilizar os recursos entre as instancias do pipeline. Sua criação é bem simples, tendo como único atributo a se destacar, a tag *force_destroy,* que autoriza, ou não, a destruição da instância, mesmo contendo arquivos salvos. 

```
resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = "example-codepipeline-artifacts"
  force_destroy = false
}
```