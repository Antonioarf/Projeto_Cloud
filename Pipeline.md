# Pipeline

<aside>
💡 Dica: cuidado com as chaves abertas e fechadas, durante a explicação algumas chaves podem ter seu par em outro segmento de codigo.

</aside>

Para a implementação do pipeline, é necessario, primeiramente, a atribuição de um nome e um *role.* Em seguida, é vinculado o *Bucket S3 (criado nas dependências),* onde serão guardados os arquivos transferidos de um estagio para o seguinte.

```makefile
resource "aws_codepipeline" "Pipeline" {
  name     = "codepipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts_bucket.bucket
    type     = "S3"
  }
```

Em seguida são definidos os tres estagios seguindo estruturas parecidas No ******stage****** inicial, destaca-se a vinculação da fonte dos arquivos, com os dados no parametro configuration, atualmente ocupado pelo nome de usuário Antonioarf do github, e o diretorio [micro-api](https://github.com/Antonioarf/micro-api), do qual a breanch master é utilizada pelo pipeline. O diretorio roda alguns comandos na etapa do build e apenas salva os arquivos na instancia do CodeDeploy, sendo assim um bom teste para garantir o bom funcionamento do pipeline.

O parametro ConnectionArn deve ser prenchido com uma conexão feita por [esse link](https://us-east-1.console.aws.amazon.com/codesuite/settings/connections?region=us-east-1&connections-meta=eyJmIjp7InRleHQiOiIifSwicyI6e30sIm4iOjIwLCJpIjowfQ) para permitir o serviço de acesso ao seu Github.

```makefile
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
        FullRepositoryId = "Antonioarf/micro-api"
        BranchName       = "master"
      }
    }
  }
```

Na fase do *****Build***** precisa-se utilizar dois ***artifacts,*** um de input para receber do *Source*, e outro para salvar a saida para o *Deploy.* No segmento configuration, é preciso apenas introduzir a instancia de build, feita nas dependencias, como responsavel pela execução.

```makefile
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
```

O *Deploy* é a fase mais dependente do tipo de projeto no qual o Pipeline está envolvido. Neste caso, foi utilizado o CodeDeploy, portanto, nas configurações atribuiram-se a aplicação e o grupo de deploy.

```makefile
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
```