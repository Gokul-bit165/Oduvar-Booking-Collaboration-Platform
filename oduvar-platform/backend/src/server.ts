import { createApp } from './app';
import { env } from './config/environment';
import { prisma } from './config/database';

async function bootstrap() {
  try {
    // Verify database connection
    await prisma.$connect();
    console.log(' Successfully connected to PostgreSQL database via Prisma');

    const app = createApp();

    const server = app.listen(env.PORT, () => {
      console.log(` Oduvar Platform Backend API is running on port ${env.PORT}`);
      console.log(` Environment: ${env.NODE_ENV}`);
      console.log(` Health check available at: http://localhost:${env.PORT}/health`);
    });

    const shutdown = async (signal: string) => {
      console.log(`Received ${signal}. Shutting down gracefully...`);
      server.close(async () => {
        await prisma.$disconnect();
        console.log('Database disconnected. Process exited.');
        process.exit(0);
      });
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (error) {
    console.error('Failed to start server:', error);
    await prisma.$disconnect();
    process.exit(1);
  }
}

bootstrap();
