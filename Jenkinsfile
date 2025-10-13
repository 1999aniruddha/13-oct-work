pipeline {
  agent any

  environment {
    TF_DIR = "terraform"
    ANSIBLE_DIR = "ansible"
    APP_DIR = "app"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        withCredentials([[$class: 'UsernamePasswordMultiBinding',
          credentialsId: 'AWS_CREDS',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {

          sh '''
            set -e
            cd $TF_DIR
            terraform init -input=false
            terraform apply -auto-approve -input=false
            terraform output -json > tf_outputs.json
            # extract public IP
            PUBLIC_IP=$(terraform output -raw public_ip)
            echo "PUBLIC_IP=${PUBLIC_IP}" > ../public_ip.env
          '''
        }
      }
    }

    stage('Ansible Deploy') {
      steps {
        // Use SSH private key credential; "deploy-key" must be created in Jenkins
        sshagent(['deploy-key']) {
          sh '''
            set -e
            # load public ip
            source public_ip.env
            mkdir -p ansible/inventory
            cat > ansible/inventory/hosts.ini <<EOF
[webservers]
${PUBLIC_IP} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
            # run ansible
            ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml --ssh-extra-args='-o StrictHostKeyChecking=no'
          '''
        }
      }
    }

    stage('Report') {
      steps {
        sh '''
          source public_ip.env
          echo "Application should be available at: http://${PUBLIC_IP}"
        '''
      }
    }
  }

  post {
    success {
      echo 'Pipeline finished successfully.'
    }
    failure {
      echo 'Pipeline failed. Check logs.'
    }
  }
}
