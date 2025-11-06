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
    withCredentials([usernamePassword(credentialsId: 'AWS_CREDS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
      dir(env.TF_DIR) {
        bat """
@echo off
set TF_PLUGIN_CACHE_DIR=%WORKSPACE%\\.terraform-plugin-cache

echo 🧠 Running Terraform Plan...
terraform plan -out=tfplan -input=false
REM show plan summary
terraform show -no-color tfplan > tfplan.txt 2>&1 || true
echo --- Begin tfplan.txt ---
type tfplan.txt
echo --- End tfplan.txt ---
"""
      }
    }
  }
}

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
set APPLY_LOG=%WORKSPACE%\\terraform\\apply.log

echo 🚀 Applying Terraform changes...
REM Run apply and capture exit code and full output (both stdout/stderr to console and file)
terraform apply -auto-approve -input=false tfplan > "%APPLY_LOG%" 2>&1
set APPLY_EXIT_CODE=%ERRORLEVEL%

echo --- Begin apply.log ---
type "%APPLY_LOG%"
echo --- End apply.log ---

REM If apply failed, print a helpful message and fail the step (non-zero exit code)
if %APPLY_EXIT_CODE% NEQ 0 (
  echo ❌ Terraform apply returned exit code %APPLY_EXIT_CODE%. See apply.log above.
  exit /b %APPLY_EXIT_CODE%
)

echo ✅ Terraform Apply succeeded.
REM Save outputs (if any)
terraform output -json > tf_outputs.json 2>nul || echo {} > tf_outputs.json

REM Try to read private_ip output (if defined) and write to target_ip.env
(for /f "delims=" %%i in ('terraform output -raw private_ip 2^>nul') do set TARGET_IP=%%i) || set TARGET_IP=
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

