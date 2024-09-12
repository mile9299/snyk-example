pipeline {
    agent any
    
    environment {
        JUICE_SHOP_REPO = 'https://github.com/mile9299/snyk-example.git'
        DOCKER_PORT = 3000 /* Default Docker port */ 
        SPECTRAL_DSN = credentials('SPECTRAL_DSN')
        CS_IMAGE_NAME = 'mile/cs-fcs'
        CS_IMAGE_TAG = '0.42.0'
        CS_CLIENT_ID = credentials('CS_CLIENT_ID')
        CS_CLIENT_SECRET = credentials('CS_CLIENT_SECRET')
        CS_USERNAME = 'mile'
        CS_PASSWORD = credentials('CS_PASSWORD')
        FALCON_REGION = 'us-1'
        PROJECT_PATH = 'git::https://github.com/hashicorp/terraform-guides.git'
    }

    tools {
        nodejs 'NodeJS 18.0.0'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: JUICE_SHOP_REPO]]])
                }
            }
        }
         stage('Falcon Cloud Security IaC Scan') {
    steps {
        script {
            def SCAN_EXIT_CODE = sh(
                script: '''
                    set +x
                    # check if required env vars are set in the build set up

                    scan_status=0
                    if [[ -z "$CS_USERNAME" || -z "$CS_PASSWORD" || -z "$CS_REGISTRY" || -z "$CS_IMAGE_NAME" || -z "$CS_IMAGE_TAG" || -z "$CS_CLIENT_ID" || -z "$CS_CLIENT_SECRET" || -z "$FALCON_REGION" || -z "$PROJECT_PATH" ]]; then
                        echo "Error: required environment variables/params are not set"
                        exit 1
                    else  
                        # login to crowdstrike registry
                        echo "Logging in to crowdstrike registry with username: $CS_USERNAME"
                        echo "$CS_PASSWORD" | docker login --username "$CS_USERNAME" --password-stdin
                        
                        if [ $? -eq 0 ]; then
                            echo "Docker login successful"
                            #  pull the fcs container target
                            echo "Pulling fcs container target from crowdstrike"
                            docker pull mile/cs-fcs:0.42.0
                            if [ $? -eq 0 ]; then
                                echo "fcs docker container image pulled successfully"
                                echo "=============== FCS IaC Scan Starts ==============="

docker run --network=host --rm "$CS_IMAGE_NAME":"$CS_IMAGE_TAG" --client-id "$CS_CLIENT_ID" --client-secret "$CS_CLIENT_SECRET" --falcon-region "$FALCON_REGION" iac scan -p "$PROJECT_PATH" --fail-on "high=10,medium=70,low=50,info=10"
                                scan_status=$?
                                echo "=============== FCS IaC Scan Ends ==============="
                            else
                                echo "Error: failed to pull fcs docker image from crowdstrike"
                                scan_status=1
                            fi
                        else
                            echo "Error: docker login failed"
                            scan_status=1
                        fi
                    fi
                ''', returnStatus: true
                )
                echo "fcs-iac-scan-status: ${SCAN_EXIT_CODE}"
                if (SCAN_EXIT_CODE == 40) {
                    echo "Scan succeeded & vulnerabilities count are ABOVE the '--fail-on' threshold; Pipeline will be marked as Success, but this stage will be marked as Unstable"
                    skipPublishingChecks: true
                    currentBuild.result = 'UNSTABLE'
                } else if (SCAN_EXIT_CODE == 0) {
                    echo "Scan succeeded & vulnerabilities count are BELOW the '--fail-on' threshold; Pipeline will be marked as Success"
                    skipPublishingChecks: true
                    skipMarkingBuildUnstable: true
                    currentBuild.result = 'Success'
                } else {
                    currentBuild.result = 'Failure'
                    error 'Unexpected scan exit code: ${SCAN_EXIT_CODE}'
                }
                
        }
    }
    post {
        success {
            echo 'Build succeeded!'
        }
        unstable {
            echo 'Build is unstable, but still considered successful!'
        }
        failure {
            echo 'Build failed!'
        }
        always {
            echo "FCS IaC Scan Execution complete.."
        }
    }
}
        stage('Test with Snyk') {
            steps {
                script {
                    snykSecurity failOnIssues: false, severity: 'critical', snykInstallation: 'snyk-manual', snykTokenId: 'SNYK'
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    echo 'Building Docker image...'
                    def dockerImage = docker.build('spooky:latest', '-f Dockerfile .')
                    echo 'Docker image built successfully!'
                }
            }
        }
        stage('Falcon Cloud Security') {
            steps {
                withCredentials([usernameColonPassword(credentialsId: 'CRWD', variable: 'FALCON_CREDENTIALS')]) {
                    crowdStrikeSecurity imageName: 'spooky', imageTag: 'latest', enforce: true, timeout: 60
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    echo 'Deploying application...'
                    // Ensure stop and remove commands don't fail the pipeline if the container isn't running
                    sh 'docker stop spooky || true'
                    sh 'docker rm spooky || true'
                    
                    // Run the Docker container
                    def containerId = sh(script: "docker run -d -P --name snyk-example snyk-example", returnStdout: true).trim()
                    def dockerHostPort = sh(script: "docker port ${containerId} ${DOCKER_PORT} | cut -d ':' -f 2", returnStdout: true).trim()
                    
                    echo "Application is running on http://localhost:${dockerHostPort}"
                }
            }
        }
    }

    post {
        success {
            echo 'Build, test, and deployment successful!'
        }
        failure {
            echo 'Build, test, or deployment failed!'
        }
    }
}
