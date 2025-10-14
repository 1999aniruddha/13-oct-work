pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')      // Replace with your Jenkins credential ID
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')  // Replace with your Jenkins credential ID
    }

    options {
        timeout(time: 60, unit: 'MINUTES')    // Prevent hanging builds
        ansiColor('xterm')
        timestamps()
    }

    stages {
        stage('Checkout SCM') {
            steps {
                echo "🔄 Checking out Git repository..."
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/1999aniruddha/13-oct-work.git',
                        credentialsId: '2d5db3f3-8f3c-45a1-909e-ce4661dfa659'
                    ]]
                ])
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    echo "⚙️ Initializing Terraform..."
                    sh 'terraform init -input=false -no-color'

                    echo "🚀 Applying Terraform..."
                    // Run Terraform in a way compatible with Jenkins durable tasks
                    sh 'terraform apply -auto-approve -input=false -no-color'
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                echo "📦 Running Ansible deployment..."
                dir('ansible') {
                    sh 'ansible-playbook -i inventory.ini deploy.yml'
                }
            }
        }

        stage('Report') {
            steps {
                echo "📊 Pipeline completed. Generating report..."
                sh 'echo "Terraform & Ansible deployment finished successfully!" > report.txt'
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline finished successfully."
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
        always {
            archiveArtifacts artifacts: '**/report.txt', allowEmptyArchive: true
            cleanWs()
        }
    }
}
