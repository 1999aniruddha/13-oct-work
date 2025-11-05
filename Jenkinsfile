pipeline {
    agent any

    environment {
        TF_DIR = "terraform"
        ANSIBLE_DIR = "ansible"
        AWS_REGION = "ap-south-1"  // ✅ Matches your Terraform setup
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
set AWS_REGION=${AWS_REGION}

echo 🔧 Initializing Terraform...
terraform init -input=false
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Terraform Init failed!
    exit /b 1
)
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
set AWS_REGION=${AWS_REGION}

echo 🧠 Running Terraform Plan...
terraform plan -out=tfplan -input=false
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Terraform Plan failed!
    exit /b 1
)
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
set AWS_REGION=${AWS_REGION}
setlocal enabledelayedexpansion

echo 🚀 Applying Terraform changes...
terraform apply -auto-approve -input=false tfplan > apply.log 2>&1
set APPLY_EXIT_CODE=%ERRORLEVEL%

if %APPLY_EXIT_CODE% NEQ 0 (
    echo ❌ Terraform Apply failed. See apply.log for details:
    type apply.log
    exit /b 1
)

echo ✅ Terraform Apply completed successfully.

REM --- Extract public_ip output ---
for /f "delims=" %%i in ('terraform output -raw public_ip 2^>nul') do set PUBLIC_IP=%%i

if not defined PUBLIC_IP (
    echo ⚠️ No public_ip output from Terraform — trying AWS CLI...
    aws ec2 describe-instances --region ${AWS_REGION} --filters "Name=tag:Name,Values=ci-cd-test" --query "Reservations[*].Instances[*].PublicIpAddress" --output text > temp_ip.txt 2>nul
    set /p PUBLIC_IP=<temp_ip.txt
)

if defined PUBLIC_IP (
    echo PUBLIC_IP=%PUBLIC_IP% > "%WORKSPACE%\\public_ip.env"
    echo ✅ Public IP captured: %PUBLIC_IP%
) else (
    echo ❌ No public IP found from Terraform or AWS.
    exit /b 1
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
for /f "tokens=1,2 delims==" %%i in (public_ip.env) do set %%i=%%j

if not defined PUBLIC_IP (
    echo ❌ No PUBLIC_IP found, skipping Ansible.
    exit /b 0
)

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
if defined PUBLIC_IP (
    echo 🌐 Application should be available at: http://%PUBLIC_IP%
) else (
    echo ⚠️ No public IP found, skipping report.
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
            echo '❌ Pipeline failed. Check logs and apply.log inside terraform folder.'
        }
        always {
            echo '🧹 Cleaning workspace and archiving outputs...'
            archiveArtifacts artifacts: '**/terraform/*.log, **/terraform/*.tfstate, **/public_ip.env', allowEmptyArchive: true
            cleanWs()
        }
    }
}

