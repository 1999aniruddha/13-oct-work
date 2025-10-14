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
                // Use usernamePassword style like your working pipeline
                withCredentials([usernamePassword(credentialsId: 'AWS_CREDS',
                                                  usernameVariable: 'AWS_ACCESS_KEY_ID',
                                                  passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                        # Persistent plugin cache
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

                        mkdir -p $ANSIBLE_DIR/inventory
                        cat > $ANSIBLE_DIR/inventory/hosts.ini <<EOF
[webservers]
${PUBLIC_IP} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

                        ansible-playbook -i $ANSIBLE_DIR/inventory/hosts.ini $ANSIBLE_DIR/site.yml --ssh-extra-args='-o StrictHostKeyChecking=no'
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
        always {
            node {
                // Only archive if file exists
                archiveArtifacts artifacts: '**/tf_outputs.json, **/public_ip.env', allowEmptyArchive: true
                cleanWs()
            }
        }
    }
}
