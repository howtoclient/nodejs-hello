# nodejs-hello
Nodejs application that contains basic k8s config yaml and aws bitbucket deploy to k8s

# deployment.yaml example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-hello
  labels:
    app: nodejs-hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodejs-hello
  template:
    metadata:
      labels:
        app: nodejs-hello
    spec:
      containers:
        - name: nodejs-hello
          readinessProbe:
            tcpSocket:
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          envFrom:
            - secretRef:
                name: nodejs-hello-secret             <-- do not forget to create ( must be created manually )
          image: [Your ECR host name/nodejs-hello]    <-- do not forget to replace
          imagePullPolicy: Always
          ports:
            - containerPort: 3000
```
# service.yaml example
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-hello
spec:
  selector:
    app: nodejs-hello
  ports:
    - name: http
      protocol: TCP
      port: 3000
      targetPort: 3000
```

# ingress.yaml example
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nodejs-hello-route
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: nodejs-hello.example.com    <-- dont forget to point subdomain to ingress load balancer
      http:
        paths:
          - path: /
            backend:
              serviceName: nodejs-hello
              servicePort: 3000
```

# bitbucket-pipelines.yaml example
-  `$AWS_ACCESS_KEY_ID` - (SECRET) aws IAM access key ID
-  `$AWS_SECRET_ACCESS_KEY` - (SECRET) aws IAM secret key ID
-  `$AWS_DEFAULT_REGION` - your aws cluster region
- `$KUBE_CONFIG` - (SECRET) result of `cat ~/.kube/config | base64`
- `$AWS_ECR_HOST` - (SECRET) host of your ECR repositories
- `$BITBUCKET_COMMIT` - commit that triggered the build ( automatic )
```yaml
image: docker:stable
definitions:
  steps:
    - step: &build-and-deploy-image
        services:
          - docker
        name: Build docker image
        script:
          - docker build -t "nodejs-hello:$BITBUCKET_COMMIT" -t "nodejs-hello:latest" .
          - pipe: atlassian/aws-ecr-push-image:1.1.2
            variables:
              AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
              AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
              AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION
              IMAGE_NAME: "nodejs-hello:$BITBUCKET_COMMIT"
              TAGS: '$BITBUCKET_COMMIT'
          - pipe: atlassian/kubectl-run:1.1.6
            variables:
              KUBE_CONFIG: $KUBE_CONFIG
              KUBECTL_COMMAND: 'apply'
              RESOURCE_PATH: './k8s'
          - pipe: atlassian/kubectl-run:1.1.6
            variables:
              KUBE_CONFIG: $KUBE_CONFIG
              KUBECTL_COMMAND: 'set image deployments/nodejs-hello nodejs-hello=$AWS_ECR_HOST/nodejs-hello:$BITBUCKET_COMMIT'

pipelines:
  branches:
    master:
      - step:
          <<: *build-and-deploy-image
          name: build docker image
          deployment: production


```
# Dockerfile example
```yaml
FROM node:12.13-alpine
WORKDIR /usr/src/app
COPY . .
COPY package*.json ./
RUN npm ci
CMD ["npm","start"]
```