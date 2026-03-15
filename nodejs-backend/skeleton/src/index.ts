import Fastify from 'fastify';

const app = Fastify({ logger: true });
const port = parseInt(process.env.PORT ?? '${{ values.port }}', 10);

app.get('/', async () => {
  return { message: 'Hello from ${{ values.name }}' };
});

app.get('/health', async () => {
  return { status: 'ok', service: '${{ values.name }}' };
});

app.listen({ port, host: '0.0.0.0' }, (err) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
});
