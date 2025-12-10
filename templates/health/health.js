/**
 * Health Check Endpoint - Node.js / Express
 *
 * Add to your Express app:
 *   const healthRoutes = require('./health');
 *   app.use(healthRoutes);
 *
 * Endpoints:
 *   GET /health       - Basic liveness check
 *   GET /health/ready - Readiness check with dependencies
 */

const express = require('express');
const router = express.Router();

// Simple liveness probe
// Returns 200 if the process is running
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Readiness probe with dependency checks
// Returns 200 only if all dependencies are available
router.get('/health/ready', async (req, res) => {
  const checks = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    checks: {}
  };

  try {
    // Database check (uncomment and adapt)
    // const dbStart = Date.now();
    // await db.query('SELECT 1');
    // checks.checks.database = {
    //   status: 'healthy',
    //   latency: Date.now() - dbStart
    // };

    // Redis check (uncomment and adapt)
    // const redisStart = Date.now();
    // await redis.ping();
    // checks.checks.redis = {
    //   status: 'healthy',
    //   latency: Date.now() - redisStart
    // };

    // Memory check
    const memUsage = process.memoryUsage();
    const memUsedMB = Math.round(memUsage.heapUsed / 1024 / 1024);
    const memTotalMB = Math.round(memUsage.heapTotal / 1024 / 1024);
    checks.checks.memory = {
      status: memUsedMB < memTotalMB * 0.9 ? 'healthy' : 'warning',
      used: `${memUsedMB}MB`,
      total: `${memTotalMB}MB`
    };

    res.status(200).json(checks);
  } catch (error) {
    checks.status = 'unhealthy';
    checks.error = error.message;
    res.status(503).json(checks);
  }
});

module.exports = router;

// Standalone usage (for testing)
// node health.js
if (require.main === module) {
  const app = express();
  app.use(router);
  const port = process.env.PORT || 3000;
  app.listen(port, () => {
    console.log(`Health check running on http://localhost:${port}/health`);
  });
}
