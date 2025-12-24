import { defineConfig, defineDocs } from 'fumadocs-mdx/config';

export const docs = defineDocs({
  dir: 'content/docs',
});

export default defineConfig({
  mdxOptions: {
    rehypeCodeOptions: {
      themes: {
        light: 'github-light',
        dark: 'github-dark',
      },
      langs: ['bash', 'shell', 'yaml', 'json', 'sql', 'typescript', 'javascript', 'tsx', 'jsx', 'css', 'html', 'markdown', 'mdx', 'dockerfile'],
    },
  },
});
