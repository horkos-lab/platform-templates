export function hello(name: string): string {
  return `Hello from ${{ values.name }}, ${name}!`;
}
