pipeline {
    agent any
    environment {
        NEXUS_CREDS = credentials('nexus-creds') // Nexus credentials containing both username and password
        NEXUS_HOST = 'nexus.ticktocktv.com' // Nexus repository hostname
        NEXUS_REPO = 'repository/nexus-repo' // Nexus repository path
        DOCKER_REPO = 'repository/docker-repo' // docker repository path
        IMAGE_NAME = 'petclinicapps' // Docker image name
        TRIVY_IMAGE = 'aquasec/trivy:latest' // Trivy Docker image
        NEXUS_IP = 'nexus-repo'
    }
    stages {
        stage('Code Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'mvn sonar:sonar'
                }   
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        // stage('Dependency Check') {
        //     steps {
        //         dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
        //         dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        //     }
        // }
        // stage('Test Code') {
        //     steps {
        //         sh 'mvn test -Dcheckstyle.skip'
        //     }
        // }
        stage('Build Artifact') {
            steps {
                sh 'mvn clean package -DskipTests -Dcheckstyle.skip'
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    def fullImageName = "${env.NEXUS_HOST}/${env.NEXUS_REPO}/${env.IMAGE_NAME}:latest"
                    sh "docker build -t ${fullImageName} ."
                }
            }
        }
        stage('Push Artifact to Nexus Repo') {
            steps {
                nexusArtifactUploader artifacts: [[artifactId: 'spring-petclinic',
                classifier: '',
                file: 'target/spring-petclinic-2.4.2.war',
                type: 'war']],
                credentialsId: 'nexus-creds',
                groupId: 'Petclinic', 
                nexusUrl: 'nexus.ticktocktv.com',
                nexusVersion: 'nexus3',
                protocol: 'https',
                repository: 'nexus-repo',
                version: '1.0'
            }
        }
        stage('Trivy fs Scan') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }
        stage('Log Into Nexus Docker Repo') {
            steps {
                script {
                    sh 'echo $NEXUS_CREDS_PSW | docker login -u $NEXUS_CREDS_USR --password-stdin ${NEXUS_IP}'
                }
            }
        }
        stage('Push to Nexus Docker Repo') {
            steps {
                script {
                    def fullImageName = "${env.NEXUS_HOST}/${env.DOCKER_REPO}/${env.IMAGE_NAME}:latest"
                    sh "docker push ${fullImageName}"
                }
            }
        }
        stage('Trivy image Scan') {
            steps {
                script {
                    def fullImageName = "${env.NEXUS_HOST}/${env.NEXUS_REPO}/${env.IMAGE_NAME}:latest"
                    sh "trivy image ${fullImageName} > trivyimage.txt"
                }
            }
        }
        stage('Deploy to stage') {
            steps {
                sshagent(['ansible-key']) {
                    sh 'ssh -t -t ec2-user@10.0.3.176 -o strictHostKeyChecking=no "ansible-playbook -i /etc/ansible/stage-hosts /etc/ansible/stage_playbook.yml"'
                }
            }
        }
        stage('check stage website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://stage.ticktocktv.com"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.ticktocktv.com", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The stage petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "The stage petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    }
                }
            }
        }
        stage('Request for Approval') {
            steps {
                timeout(activity: true, time: 10) {
                    input message: 'Needs Approval ', submitter: 'admin'
                }
            }
        }
        stage('Deploy to prod') {
            steps {
                sshagent(['ansible-key']) {
                    sh 'ssh -t -t ec2-user@10.0.3.176 -o strictHostKeyChecking=no "ansible-playbook -i /etc/ansible/prod-hosts /etc/ansible/prod_playbook.yml"'
                }
            }
        }
        stage('check prod website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://prod.ticktocktv.com"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.ticktocktv.com", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The prod petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "The prod petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }
}
