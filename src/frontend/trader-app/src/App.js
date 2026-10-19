
import Market from './components/Market'
import Trade from './components/Trade'
import Error from './components/Error'
import Test from './components/Test'
import Train from './components/Train'
import Chat from './components/Chat'

import TraderAppBar from './components/TraderAppBar'

import './App.css';
import { Route, NavLink, HashRouter, BrowserRouter, Routes } from "react-router-dom";

function App() {
  return (
    <HashRouter>
      <div className="App">
        <TraderAppBar />
        <div className="content">
          <Routes>
            <Route exact path="/" element={<Trade />} />
            <Route path="/market" element={<Market />} />
            <Route path="/error" element={<Error />} />
            <Route path="/test" element={<Test />} />
            <Route path="/train" element={<Train />} />
            <Route path="/chat" element={<Chat />} />
          </Routes>
        </div>
      </div>
    </HashRouter>
  );
}

export default App;