import { ApolloServer } from '@apollo/server';
import fastify from 'fastify';
import cors from '@fastify/cors';
import { fastifyApolloDrainPlugin, fastifyApolloHandler } from '@as-integrations/fastify';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { resolvers } from './resolvers';
import { createDbClient } from './context';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Load GraphQL schema
 */
const typeDefs = readFileSync(
  join(__dirname, 'schema.graphql'),
  'utf-8'
);

/**
 * Main entry point
 */
async function main() {
  const app = fastify();

  // Enable CORS for frontend
  await app.register(cors, {
    origin: true, // Allow all origins in development
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
  });

  // Create Apollo Server
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    plugins: [fastifyApolloDrainPlugin(app)],
  });

  await server.start();

  // GraphQL endpoint
  app.route({
    url: '/graphql',
    method: ['GET', 'POST'],
    handler: fastifyApolloHandler(server, {
      context: async () => ({
        dbClient: createDbClient(),
      }),
    }),
  });

  // Health check endpoint
  app.get('/health', async () => {
    return { status: 'ok' };
  });

  const port = Number(process.env.PORT) || 4000;
  const host = process.env.HOST || '0.0.0.0';

  await app.listen({ port, host });

  console.log(`🚀 GraphQL server ready at http://${host}:${port}/graphql`);
  console.log(`📊 Health check: http://${host}:${port}/health`);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

