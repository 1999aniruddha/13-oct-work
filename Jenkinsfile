pipeline {
    agent any

    environment {
        TF_DIR = "terraform"
        ANSIBLE_DIR = "ansible"
        APP_DIR = "app"
        TF_LOG = "INFO"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'AWS_CREDS',
                                                  usernameVariable: 'AWS_ACCESS_KEY_ID',
                                                  passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                        # 🧹 Clean old Terraform caches to avoid plugin corruption
                        rm -rf .terraform .terraform.lock.hcl $WORKSPACE/.terraform-plugin-cache

                        # Workspace-based Terraform plugin cache
                        export TF_PLUGIN_CACHE_DIR=$WORKSPACE/.terraform-plugin-cache
                        mkdir -p $TF_PLUGIN_CACHE_DIR
                        echo "🔧 Using Terraform plugin cache at $TF_PLUGIN_CACHE_DIR"

                        # Enable detailed Terraform logs
                        export TF_LOG_PATH=$WORKSPACE/terraform/terraform.log

                        echo "🚀 Initializing Terraform..."
                        terraform init -input=false

                        echo "🧠 Planning infrastructure changes..."
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            options {
                timeout(time: 15, unit: 'MINUTES')
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'AWS_CREDS',
                                                  usernameVariable: 'AWS_ACCESS_KEY_ID',
                                                  passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export TF_PLUGIN_CACHE_DIR=$WORKSPACE/.terraform-plugin-cache
                        export TF_LOG_PATH=$WORKSPACE/terraform/terraform.log

                        echo "🚀 Applying Terraform changes..."
                        terraform apply -auto-approve -input=false tfplan

                        echo "📤 Extracting Terraform outputs..."
                        terraform output -json > tf_outputs.json || echo '{}' > tf_outputs.json

                        if terraform output -raw public_ip >/dev/null 2>&1; then
                          PUBLIC_IP=$(terraform output -raw public_ip)
                          echo "PUBLIC_IP=${PUBLIC_IP}" > ../public_ip.env
                          echo "✅ Public IP captured: ${PUBLIC_IP}"
                        else
                          echo "⚠️  No public_ip output found."
                        fi
                    '''
                }
            }
        }

        stage('Ansible Deploy') {
            when {
                expression { fileExists('public_ip.env') }
            }
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

                        echo "🚀 Running Ansible playbook on ${PUBLIC_IP}..."
                        ansible-playbook -i $ANSIBLE_DIR/inventory/hosts.ini $ANSIBLE_DIR/site.yml --ssh-extra-args='-o StrictHostKeyChecking=no'
                    '''
                }
            }
        }

        stage('Report') {
            when {
                expression { fileExists('public_ip.env') }
            }
            steps {
                sh '''
                    source public_ip.env
                    echo "🌐 Application should be available at: http://${PUBLIC_IP}"
                '''
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline finished successfully.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs (terraform/terraform.log for details).'
        }
        always {
            archiveArtifacts artifacts: '**/tf_outputs.json, **/public_ip.env, **/terraform.log', allowEmptyArchive: true
            cleanWs()
        }
    }
}
