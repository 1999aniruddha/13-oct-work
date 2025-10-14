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
    withCredentials([usernamePassword(credentialsId: 'AWS_CREDS',
                                      usernameVariable: 'AWS_ACCESS_KEY_ID',
                                      passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {

      sh '''
        set -e
        cd $TF_DIR

        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

        # Persistent plugin cache (reuses AWS provider between runs)
        export TF_PLUGIN_CACHE_DIR=/var/terraform-plugin-cache
        mkdir -p $TF_PLUGIN_CACHE_DIR

        echo "🔧 Using Terraform plugin cache at $TF_PLUGIN_CACHE_DIR"

        terraform init -input=false
        terraform plan -out=tfplan
        terraform apply -auto-approve -input=false -parallelism=5

        terraform output -json > tf_outputs.json
        PUBLIC_IP=$(terraform output -raw public_ip)
        echo "PUBLIC_IP=${PUBLIC_IP}" > ../public_ip.env
      '''
    }
  }
}


    stage('Ansible Deploy') {
      steps {
        sshagent(['deploy-key']) {
          sh '''
            set -e
            source public_ip.env

            mkdir -p ansible/inventory
            cat > ansible/inventory/hosts.ini <<EOF
[webservers]
${PUBLIC_IP} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

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
      echo '✅ Pipeline finished successfully.'
    }
    failure {
      echo '❌ Pipeline failed. Check logs.'
    }
  }
}
