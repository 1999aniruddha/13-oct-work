pipeline {
    agent any

    environment {
        TF_DIR = "terraform"
        ANSIBLE_DIR = "ansible"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "📦 Checking out source code..."
                git(
                    url: 'https://github.com/1999aniruddha/13-oct-work.git',
                    branch: 'main'
                    // Remove credentialsId if repo is public
                )
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'AWS_CREDS',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    dir(env.TF_DIR) {
                        bat """
@echo off
REM Setting Terraform plugin cache directory
set TF_PLUGIN_CACHE_DIR=%WORKSPACE%\\.terraform-plugin-cache
if not exist "%TF_PLUGIN_CACHE_DIR%" mkdir "%TF_PLUGIN_CACHE_DIR%"

set TF_LOG=INFO
set TF_LOG_PATH=%WORKSPACE%\\terraform.log

echo 🔧 Initializing Terraform...
terraform init -input=false
"""
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'AWS_CREDS',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    dir(env.TF_DIR) {
                        bat """
@echo off
set TF_PLUGIN_CACHE_DIR=%WORKSPACE%\\.terraform-plugin-cache
set TF_LOG=INFO
set TF_LOG_PATH=%WORKSPACE%\\terraform.log

echo 🧠 Running Terraform Plan...
terraform plan -out=tfplan -input=false
"""
                    }
                }
            }
        }

        stage('Terraform Apply') {
            options { timeout(time: 30, unit: 'MINUTES') }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'AWS_CREDS',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    dir(env.TF_DIR) {
                        bat """
@echo off
set TF_PLUGIN_CACHE_DIR=%WORKSPACE%\\.terraform-plugin-cache
set TF_LOG=INFO
set TF_LOG_PATH=%WORKSPACE%\\terraform.log

echo 🚀 Applying Terraform changes...
terraform apply -auto-approve -input=false tfplan

echo 📤 Extracting Terraform outputs...
terraform output -json > tf_outputs.json || echo {} > tf_outputs.json

REM Capture public IP if output exists
for /f "delims=" %%i in ('terraform output -raw public_ip 2^>nul') do set PUBLIC_IP=%%i
if defined PUBLIC_IP (
    echo PUBLIC_IP=%PUBLIC_IP% > "%WORKSPACE%\\public_ip.env"
    echo ✅ Public IP captured: %PUBLIC_IP%
) else (
    echo ⚠️ No public_ip output found.
)
"""
                    }
                }
            }
        }

        stage('Ansible Deploy') {
            when { expression { fileExists('public_ip.env') } }
            steps {
                sshagent(['deploy-key']) {
                    bat """
@echo off
REM Load public IP
for /f "tokens=1,2 delims==" %%i in (public_ip.env) do set %%i=%%j

REM Create inventory
if not exist "%ANSIBLE_DIR%\\inventory" mkdir "%ANSIBLE_DIR%\\inventory"
(
echo [webservers]
echo %PUBLIC_IP% ansible_user=ubuntu ansible_ssh_common_args="-o StrictHostKeyChecking=no"
) > "%ANSIBLE_DIR%\\inventory\\hosts.ini"

echo 🚀 Running Ansible playbook on %PUBLIC_IP%...
ansible-playbook -i "%ANSIBLE_DIR%\\inventory\\hosts.ini" "%ANSIBLE_DIR%\\site.yml" --ssh-common-args="-o StrictHostKeyChecking=no"
"""
                }
            }
        }

        stage('Report') {
            when { expression { fileExists('public_ip.env') } }
            steps {
                bat """
@echo off
for /f "tokens=1,2 delims==" %%i in (public_ip.env) do set %%i=%%j
echo 🌐 Application should be available at: http://%PUBLIC_IP%
"""
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
            echo '🧹 Cleaning workspace and archiving outputs...'
            archiveArtifacts artifacts: '**/terraform/tf_outputs.json, **/public_ip.env, **/terraform/terraform.log', allowEmptyArchive: true
            cleanWs()
        }
    }
}
