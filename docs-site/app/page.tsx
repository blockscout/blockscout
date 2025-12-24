import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-4">Lux Explorer Documentation</h1>
        <p className="text-lg text-gray-600 dark:text-gray-400 mb-8">
          Blockchain explorer for Lux Network based on Blockscout
        </p>
        <Link
          href="/docs"
          className="inline-flex items-center justify-center rounded-md bg-blue-600 px-6 py-3 text-white font-medium hover:bg-blue-700 transition-colors"
        >
          View Documentation
        </Link>
      </div>
    </main>
  );
}
