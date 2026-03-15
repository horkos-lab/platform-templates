import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  template: `
    <main style="font-family: sans-serif; text-align: center; margin-top: 4rem">
      <h1>${{ values.name }}</h1>
      <p>Angular + TypeScript</p>
    </main>
  `,
})
export class AppComponent {}
