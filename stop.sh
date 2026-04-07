echo "Stopping AWS resources..."

aws ecs update-service \
  --cluster restaurant-cluster \
  --service restaurant-backend \
  --desired-count 0 \
  --region us-east-1 > /dev/null

aws rds stop-db-instance \
  --db-instance-identifier restaurant-mysql \
  --region us-east-1 > /dev/null

echo "Done! ECS and RDS stopped."
