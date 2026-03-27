import { BrowserRouter, Routes, Route } from 'react-router-dom';

// TODO: Phase 1 — implement screens
// import Timeline from './pages/Timeline';
// import AssetDetail from './pages/AssetDetail';
// import Login from './pages/Login';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Placeholder title="Timeline" />} />
        <Route path="/search" element={<Placeholder title="Search" />} />
        <Route path="/map" element={<Placeholder title="Map" />} />
        <Route path="/albums" element={<Placeholder title="Albums" />} />
        <Route path="/people" element={<Placeholder title="People" />} />
        <Route path="/favorites" element={<Placeholder title="Favorites" />} />
        <Route path="/archive" element={<Placeholder title="Archive" />} />
        <Route path="/trash" element={<Placeholder title="Trash" />} />
        <Route path="/settings" element={<Placeholder title="Settings" />} />
        <Route path="/admin" element={<Placeholder title="Admin" />} />
        <Route path="/share/:token" element={<Placeholder title="Shared View" />} />
      </Routes>
    </BrowserRouter>
  );
}

function Placeholder({ title }: { title: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh', fontFamily: 'system-ui' }}>
      <div style={{ textAlign: 'center' }}>
        <h1 style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>Reframe</h1>
        <p style={{ color: '#666' }}>{title} — Coming soon</p>
      </div>
    </div>
  );
}

export default App;
