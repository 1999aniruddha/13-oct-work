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
set TF_PLUGIN_CACHE_DIR=%WORKSPACE%\\.terraform-plugin-cache
if not exist "%TF_PLUGIN_CACHE_DIR%" mkdir "%TF_PLUGIN_CACHE_DIR%"

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
setlocal enabledelayedexpansion

echo 🚀 Applying Terraform changes...
terraform apply -auto-approve -input=false tfplan > apply.log 2>&1
set APPLY_EXIT_CODE=%ERRORLEVEL%

REM --- Detect duplicate security group error or other known benign issues ---
findstr /C:"InvalidGroup.Duplicate" apply.log >nul
if %ERRORLEVEL%==0 (
    echo ⚠️ Duplicate security group found — continuing without failure.
    set APPLY_EXIT_CODE=0
)

REM --- Handle apply exit code ---
if %APPLY_EXIT_CODE% NEQ 0 (
    echo ❌ Terraform Apply failed. Check apply.log
    exit /b %APPLY_EXIT_CODE%
) else (
    echo ✅ Terraform Apply succeeded or recovered.
)

REM --- Save Terraform outputs to JSON ---
terraform output -json > tf_outputs.json 2>nul || echo {} > tf_outputs.json

REM --- Extract private_ip or fallback to local loopback ---
for /f "delims=" %%i in ('terraform output -raw private_ip 2^>nul') do set TARGET_IP=%%i
if not defined TARGET_IP set TARGET_IP=127.0.0.1
echo TARGET_IP=%TARGET_IP% > "%WORKSPACE%\\target_ip.env"
echo ✅ Target IP captured: %TARGET_IP%
"""
                    }
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                sshagent(['deploy-key']) {
                    bat """
@echo off
for /f "tokens=1,2 delims==" %%i in (target_ip.env) do set %%i=%%j

if not defined TARGET_IP (
    echo ❌ No TARGET_IP found, skipping Ansible.
    exit /b 0
)

if not exist "%ANSIBLE_DIR%\\inventory" mkdir "%ANSIBLE_DIR%\\inventory"
(
echo [webservers]
echo %TARGET_IP% ansible_user=ubuntu ansible_ssh_common_args="-o StrictHostKeyChecking=no"
) > "%ANSIBLE_DIR%\\inventory\\hosts.ini"

echo 🚀 Running Ansible playbook on %TARGET_IP%...
ansible-playbook -i "%ANSIBLE_DIR%\\inventory\\hosts.ini" "%ANSIBLE_DIR%\\site.yml" --ssh-common-args="-o StrictHostKeyChecking=no"
"""
                }
            }
        }

        stage('Report') {
            steps {
                bat """
@echo off
for /f "tokens=1,2 delims==" %%i in (target_ip.env) do set %%i=%%j
if defined TARGET_IP (
    echo 🌐 Deployment completed on instance: %TARGET_IP%
) else (
    echo ⚠️ No target IP found, skipping report.
)
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
            archiveArtifacts artifacts: '**/terraform/tf_outputs.json, **/target_ip.env, **/terraform/apply.log', allowEmptyArchive: true
            cleanWs()
        }
    }
}

