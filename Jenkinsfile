pipeline {
    agent any // Jenkins agent with git, docker, aws cli, kubectl

    environment {
        DOCKER_IMAGE_NAME        = "aayush786/netflix-clone" // YOUR_DOCKERHUB_USERNAME/IMAGE_NAME
        K8S_DEPLOYMENT_FILE      = "k8s/netflix-clone-deployment.yaml"
        K8S_INGRESS_FILE         = "k8s/netflix-clone-ingress.yaml"
        K8S_NAMESPACE            = "default"
        APP_LABEL                = "app=netflix-clone"
        DEPLOYMENT_NAME          = "netflix-clone"
        INGRESS_NAME             = "netflix-clone-ingress" // Match name in your ingress.yaml
        AWS_REGION               = "us-east-1"
        EKS_CLUSTER_NAME         = "netflix-eks-cluster"
    }

    parameters {
        string(name: 'TMDB_V3_API_KEY', defaultValue: '', description: 'TMDB v3 API Key for Docker build')
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Code (EKS Branch)') {
            steps {
                git branch: 'feature/eks-deployment', url: 'https://github.com/Aayush786-21/netflix-.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    if (params.TMDB_V3_API_KEY == null || params.TMDB_V3_API_KEY.trim().isEmpty()) {
                        error "TMDB_V3_API_KEY parameter is required."
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

        stage('Deploy to EKS') {
            steps {
                // Use 'withAWS' if Pipeline AWS Steps plugin is installed and configured
                // This sets AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION etc.
                // from the Jenkins credential.
                withAWS(credentials: 'aws-eks-deploy-credentials', region: env.AWS_REGION) {
                    script {
                        // Kubeconfig file that Jenkins will use
                        def kubeconfigFilePath = "${env.WORKSPACE}/eks_kubeconfig"

                        echo "Updating kubeconfig for EKS cluster: ${env.EKS_CLUSTER_NAME} in region ${env.AWS_REGION}"
                        // This command uses the AWS credentials (from withAWS) to fetch/update the kubeconfig
                        // and writes it to a temporary file in the workspace.
                        sh "aws eks update-kubeconfig --name ${env.EKS_CLUSTER_NAME} --region ${env.AWS_REGION} --kubeconfig ${kubeconfigFilePath}"

                        echo "Applying Kubernetes manifests to EKS..."
                        // Apply Secret (ensure it's created in EKS, e.g. manually or via another pipeline step)
                        // Example: Creating/Updating the secret if defined in a YAML file
                        // sh "kubectl --kubeconfig ${kubeconfigFilePath} apply -f k8s/netflix-clone-secret.yaml -n ${env.K8S_NAMESPACE}"
                        // Or ensure it's created manually in EKS before this pipeline runs.
                        
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} apply -f ${env.K8S_DEPLOYMENT_FILE} -n ${env.K8S_NAMESPACE}"
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} apply -f ${env.K8S_INGRESS_FILE} -n ${env.K8S_NAMESPACE}"
                        
                        echo "Waiting for deployment rollout on EKS..."
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} rollout status deployment/${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} --timeout=300s"
                        
                        echo "EKS Deployment status:"
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} get deployment ${env.DEPLOYMENT_NAME} -n ${env.K8S_NAMESPACE} -o wide"
                        
                        echo "EKS Pod status:"
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} get pods -n ${env.K8S_NAMESPACE} -l ${env.APP_LABEL} -o wide"
                        
                        echo "EKS Service status:"
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} get svc ${env.DEPLOYMENT_NAME}-svc -n ${env.K8S_NAMESPACE}"
                        
                        echo "EKS Ingress status (waiting for ALB DNS name...):"
                        // It can take a few minutes for the ALB to be provisioned and the DNS name to appear
                        sh "kubectl --kubeconfig ${kubeconfigFilePath} get ingress ${env.INGRESS_NAME} -n ${env.K8S_NAMESPACE} -o wide"
                        echo "Note: The ALB DNS name might take 5-10 minutes to become fully available and propagate."
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
            sh 'docker logout || true'
            script {
                try {
                    sh "docker rmi ${env.DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} || true"
                    sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest || true"
                } catch (err) {
                    echo "Failed to remove local docker images: ${err}"
                }
            }
            deleteDir()
        }
        success {
            echo 'EKS Pipeline succeeded!'
        }
        failure {
            echo 'EKS Pipeline failed!'
        }
    }
}
