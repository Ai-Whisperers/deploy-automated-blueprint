/**
 * Bull Worker Template
 * Background job processing for Node.js applications
 *
 * Setup:
 *   npm install bull ioredis
 *
 * Usage:
 *   node workers/bull.js
 *
 * Docker Compose service:
 *   worker:
 *     build: .
 *     command: node workers/bull.js
 *     env_file: .env
 *     depends_on:
 *       - redis
 */

const Bull = require('bull');

// ===========================================
// Configuration
// ===========================================

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const defaultJobOptions = {
  removeOnComplete: 100,  // Keep last 100 completed jobs
  removeOnFail: 50,       // Keep last 50 failed jobs
  attempts: 3,
  backoff: {
    type: 'exponential',
    delay: 1000,
  },
};

// ===========================================
// Queue Definitions
// ===========================================

const queues = {
  default: new Bull('default', REDIS_URL, { defaultJobOptions }),
  highPriority: new Bull('high-priority', REDIS_URL, { defaultJobOptions }),
  scheduled: new Bull('scheduled', REDIS_URL, { defaultJobOptions }),
};

// ===========================================
// Job Processors
// ===========================================

// Default queue processor
queues.default.process('*', async (job) => {
  console.log(`Processing job ${job.id}: ${job.name}`);

  try {
    // Route to specific handlers based on job name
    switch (job.name) {
      case 'sendEmail':
        return await handleSendEmail(job.data);
      case 'processImage':
        return await handleProcessImage(job.data);
      case 'generateReport':
        return await handleGenerateReport(job.data);
      default:
        console.log(`Unknown job type: ${job.name}`);
        return { status: 'skipped', reason: 'unknown job type' };
    }
  } catch (error) {
    console.error(`Job ${job.id} failed:`, error);
    throw error;
  }
});

// High priority queue processor (more concurrency)
queues.highPriority.process(5, async (job) => {
  console.log(`Processing high priority job ${job.id}`);
  return await handleHighPriorityJob(job.data);
});

// ===========================================
// Job Handlers
// ===========================================

async function handleSendEmail(data) {
  const { to, subject, body } = data;
  console.log(`Sending email to ${to}: ${subject}`);
  // Add your email sending logic here
  return { status: 'sent', to };
}

async function handleProcessImage(data) {
  const { imageUrl, operations } = data;
  console.log(`Processing image: ${imageUrl}`);
  // Add your image processing logic here
  return { status: 'processed', imageUrl };
}

async function handleGenerateReport(data) {
  const { reportType, dateRange } = data;
  console.log(`Generating ${reportType} report`);
  // Add your report generation logic here
  return { status: 'generated', reportType };
}

async function handleHighPriorityJob(data) {
  console.log('Processing high priority job:', data);
  return { status: 'completed', data };
}

// ===========================================
// Scheduled Jobs (Repeatable)
// ===========================================

async function setupScheduledJobs() {
  // Clean up old jobs daily at midnight
  await queues.scheduled.add(
    'cleanup',
    {},
    {
      repeat: { cron: '0 0 * * *' },
      jobId: 'daily-cleanup',
    }
  );

  // Health check every 5 minutes
  await queues.scheduled.add(
    'healthCheck',
    {},
    {
      repeat: { every: 5 * 60 * 1000 },
      jobId: 'health-check',
    }
  );
}

queues.scheduled.process('cleanup', async () => {
  console.log('Running scheduled cleanup');
  // Add cleanup logic here
  return { status: 'cleaned' };
});

queues.scheduled.process('healthCheck', async () => {
  return { status: 'healthy', timestamp: new Date().toISOString() };
});

// ===========================================
// Event Handlers
// ===========================================

Object.entries(queues).forEach(([name, queue]) => {
  queue.on('completed', (job, result) => {
    console.log(`[${name}] Job ${job.id} completed:`, result);
  });

  queue.on('failed', (job, err) => {
    console.error(`[${name}] Job ${job.id} failed:`, err.message);
    // Add alerting/monitoring here
  });

  queue.on('stalled', (job) => {
    console.warn(`[${name}] Job ${job.id} stalled`);
  });

  queue.on('error', (error) => {
    console.error(`[${name}] Queue error:`, error);
  });
});

// ===========================================
// Graceful Shutdown
// ===========================================

async function shutdown() {
  console.log('Shutting down workers...');

  await Promise.all(
    Object.values(queues).map(queue => queue.close())
  );

  console.log('Workers shut down successfully');
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// ===========================================
// Startup
// ===========================================

async function start() {
  console.log('Starting Bull workers...');
  console.log(`Redis URL: ${REDIS_URL}`);

  await setupScheduledJobs();

  console.log('Workers started. Waiting for jobs...');
  console.log('Queues:', Object.keys(queues).join(', '));
}

start().catch((error) => {
  console.error('Failed to start workers:', error);
  process.exit(1);
});

// ===========================================
// Export for API usage
// ===========================================

module.exports = {
  queues,

  // Helper to add jobs from your API
  addJob: async (queueName, jobName, data, options = {}) => {
    const queue = queues[queueName] || queues.default;
    return await queue.add(jobName, data, options);
  },

  // Get job status
  getJob: async (queueName, jobId) => {
    const queue = queues[queueName] || queues.default;
    return await queue.getJob(jobId);
  },
};
