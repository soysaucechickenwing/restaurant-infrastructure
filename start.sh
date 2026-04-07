echo "Starting AWS resources..."

aws rds start-db-instance \
  --db-instance-identifier restaurant-mysql \
  --region us-east-1 > /dev/null

echo "Waiting for RDS to start (3 minutes)..."
sleep 180

aws ecs update-service \
  --cluster restaurant-cluster \
  --service restaurant-backend \
  --desired-count 1 \
  --region us-east-1 > /dev/null

echo "Done! Everything is running."
