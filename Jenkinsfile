pipeline {
    agent any

    environment {
        DOCKER_IMAGE_NAME        = "aayush786/netflix-clone" // Replace with YOUR Docker Hub Username/ImageName
        K8S_DEPLOYMENT_FILE      = "k8s/netflix-clone-deployment.yaml" // Path to your K8s manifest in the repo
        K8S_NAMESPACE            = "default" // Namespace for deployment and where the secret is
        APP_LABEL                = "app=netflix-clone" // Label to select your app's K8s resources
        DEPLOYMENT_NAME          = "netflix-clone"     // Name of your K8s Deployment object
        SERVICE_NAME             = "netflix-clone-svc" // Name of your K8s Service object
    }

    parameters {
        string(name: 'TMDB_V3_API_KEY', defaultValue: '', description: 'TMDB v3 API Key required for the Docker build')
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                cleanWs() // Clean the workspace before starting
            }
        }

        stage('Checkout Code') {
            steps {
                // Ensure your Jenkins job is configured to checkout the 'staging' branch,
                // or explicitly specify it here if needed for multibranch pipelines.
                // For a simple pipeline job, configuring the branch in the job UI is often enough.
                checkout scm // This checks out based on the SCM configuration of the Jenkins job
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    if (params.TMDB_V3_API_KEY == null || params.TMDB_V3_API_KEY.trim().isEmpty()) {
                        error "TMDB_V3_API_KEY parameter is required and cannot be empty for the Docker build."
                    }
                    sh "docker build --build-arg TMDB_V3_API_KEY=${params.TMDB_V3_API_KEY} -t ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} -t ${env.DOCKER_IMAGE_NAME}:latest ."
                }
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                }
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                sh "docker push ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "docker push ${env.DOCKER_IMAGE_NAME}:latest"
            }
        }

        stage('Deploy to Kind Kubernetes') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'kind-netflix-cluster-kubeconfig', variable: 'KUBECONFIG_PATH')]) {
                        echo "Applying Kubernetes manifests from ${env.K8S_DEPLOYMENT_FILE}..."
                        sh "kubectl --kubeconfig $KUBECONFIG_PATH apply -f ${env.K8S_DEPLOYMENT_FILE} -n ${env.K8S_NAMESPACE}"
                        
                        echo "Waiting for deployment rollout of ${env.DEPLOYMENT_NAME}..."
                        sh "kubectl --kubeconfig $KUBECONFIG_PATH rollout status deployment/${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} --timeout=180s"
                        
                        echo "Deployment status:"
                        sh "kubectl --kubeconfig $KUBECONFIG_PATH get deployment ${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} -o wide"
                        
                        echo "Pod status:"
                        sh "kubectl --kubeconfig $KUBECONFIG_PATH get pods -n ${env.K8S_NAMESPACE} -l ${env.APP_LABEL} -o wide"
                        
                        echo "Service status:"
                        sh "kubectl --kubeconfig $KUBECONFIG_PATH get svc ${env.SERVICE_NAME} -n ${env.K8S_NAMESPACE}"
                    }
                }
            }
        }
    } // End of stages

    post {
        always {
            echo 'Pipeline finished.'
            // Logout from Docker Hub if logged in
            sh 'docker logout || true'

            // Clean up local Docker images on the agent
            script {
                try {
                    sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} || true"
                    // Be cautious with removing ':latest' if it's actively used or if another build might need it quickly.
                    // For this CI setup, it's generally okay as we retag latest each time.
                    sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest || true"
                } catch (err) {
                    echo "Warning: Failed to remove local docker images: ${err.getMessage()}"
                }
            }
            deleteDir() // Clean up workspace again
        }
        success {
            echo 'Pipeline succeeded!'
            // You can add notification steps here (e.g., email, Slack)
        }
        failure {
            echo 'Pipeline failed!'
            // You can add notification steps here
        }
    }
}
