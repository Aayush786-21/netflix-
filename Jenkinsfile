// Jenkinsfile
pipeline {
    agent any // Runs on any available Jenkins agent (our jenkins VM)

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials') // Jenkins credential ID for Docker Hub
        DOCKER_IMAGE_NAME = "aayush786/netflix-clone" 
    }

    parameters {
        string(name: 'TMDB_V3_API_KEY', defaultValue: '', description: 'TMDB v3 API Key required for the build. Get from themoviedb.org.')
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out staging branch from ${env.GIT_URL}"
                // GIT_BRANCH is automatically set to 'staging' due to job config
                // GIT_URL is automatically set from job config
                checkout scm
            }
        }

        stage('Validate Parameters') {
            steps {
                script {
                    if (params.TMDB_V3_API_KEY == null || params.TMDB_V3_API_KEY.trim().isEmpty()) {
                        error "TMDB_V3_API_KEY parameter is required and cannot be empty."
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image ${DOCKER_IMAGE_NAME}..."
                // The Dockerfile uses ARG TMDB_V3_API_KEY
                // It then sets ENV VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}
                sh "docker build --build-arg TMDB_V3_API_KEY=\"${params.TMDB_V3_API_KEY}\" -t ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} -t ${DOCKER_IMAGE_NAME}:latest ."
            }
        }

        stage('Login to Docker Hub') {
            steps {
                echo "Logging into Docker Hub..."
                // DOCKERHUB_CREDENTIALS_USR and DOCKERHUB_CREDENTIALS_PSW are automatically provided
                // by withCredentials when 'dockerhub-credentials' is a Username/Password credential.
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                }
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                echo "Pushing ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} to Docker Hub..."
                sh "docker push ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                
                echo "Pushing ${DOCKER_IMAGE_NAME}:latest to Docker Hub..."
                sh "docker push ${DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('Cleanup Docker Image (local agent)') {
            // Optional: clean up the built image from the Jenkins agent
            steps {
                echo "Cleaning up local Docker images on agent..."
                sh "docker rmi ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} || true"
                sh "docker rmi ${DOCKER_IMAGE_NAME}:latest || true"
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            echo 'Logging out from Docker Hub...'
            sh 'docker logout || true' // Logout from Docker Hub, || true to not fail if not logged in
        }
        success {
            echo 'Pipeline Succeeded!'
            // TODO: Add notification or trigger next step (e.g., deployment)
        }
        failure {
            echo 'Pipeline Failed!'
            // TODO: Add notification
        }
    }
}
