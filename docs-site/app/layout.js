import './globals.css';

export const metadata = {
  title: 'Stackup Docs',
  description:
    'Production-shaped Kubernetes on a laptop: ArgoCD app-of-apps, Argo Rollouts canary, kube-prometheus-stack, all from make up.',
};

function Header() {
  return (
    <header className="site-header">
      <div className="inner">
        <a className="brand" href="/">
          Stackup
        </a>
        <nav className="nav">
          <a href="/">Overview</a>
          <a href="/getting-started/">Getting Started</a>
          <a href="/architecture/">Architecture</a>
          <a href="/gitops-canary/">GitOps &amp; Canary</a>
          <a href="https://github.com/ykstorm/stackup">GitHub</a>
        </nav>
      </div>
    </header>
  );
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <Header />
        <main>{children}</main>
        <footer>
          Stackup — Apache License 2.0. Built with Next.js static export.{' '}
          <a href="https://github.com/ykstorm/stackup">Source on GitHub</a>.
        </footer>
      </body>
    </html>
  );
}
