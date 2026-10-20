
import { startBrowserSdk } from '@elastic/opentelemetry-browser';
import axios from "axios";
import { v4 as uuidv4 } from 'uuid';
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

var otlpIngestUrl = window.location.protocol + window.location.host + '/telemetry/'
var serviceName = "trader-app-web"
var serviceVersion = "1.0"
var sessionId = uuidv4();

axios.defaults.headers.common['baggage'] = `com.example.client_session_id=${sessionId},com.example.frontend_name=${serviceName},com.example.frontend_version=${serviceVersion}`;

startBrowserSdk({
  serviceName: serviceName,
  serviceVersion: serviceVersion,
  otlpEndpoint: otlpIngestUrl,
  resourceAttributes: {
    'com.example.client_session_id': sessionId
  },
  exportConfig: {
      url: otlpIngestUrl
    }
});
console.log(otlpIngestUrl)

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
