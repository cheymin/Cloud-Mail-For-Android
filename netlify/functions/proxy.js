const fetch = require('node-fetch');

const NETLIFY_FREE_BANDWIDTH = 100 * 1024 * 1024 * 1024;
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'admin123456';
const SITE_URL = process.env.URL || 'https://your-site.netlify.app';

function getMonthKey() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

function getResetDate() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() + 1, 1);
}

async function getStore(context) {
  if (context?.clientContext?.getStore) {
    return context.clientContext.getStore('vpn-data');
  }
  return null;
}

async function getUsage(store) {
  const monthKey = getMonthKey();
  const defaultUsage = { bytes: 0, requests: 0, monthKey };
  
  if (!store) {
    return defaultUsage;
  }
  
  try {
    const data = await store.get(monthKey);
    if (data) {
      const parsed = JSON.parse(data);
      if (parsed.monthKey === monthKey) {
        return parsed;
      }
    }
  } catch (e) {
    console.error('getUsage error:', e);
  }
  
  return defaultUsage;
}

async function updateUsage(store, bytes) {
  const monthKey = getMonthKey();
  const current = await getUsage(store);
  
  current.bytes += bytes;
  current.requests += 1;
  current.monthKey = monthKey;
  
  if (store) {
    try {
      await store.set(monthKey, JSON.stringify(current));
    } catch (e) {
      console.error('updateUsage error:', e);
    }
  }
  
  return current;
}

async function getUserConfig(store, userId) {
  if (!store) return null;
  
  try {
    const data = await store.get(`user_${userId}`);
    if (data) {
      return JSON.parse(data);
    }
  } catch (e) {
    console.error('getUserConfig error:', e);
  }
  
  return null;
}

async function setUserConfig(store, userId, config) {
  if (!store) return false;
  
  try {
    await store.set(`user_${userId}`, JSON.stringify(config));
    return true;
  } catch (e) {
    console.error('setUserConfig error:', e);
    return false;
  }
}

function generateUserId() {
  return Math.random().toString(36).substring(2, 10) + Date.now().toString(36);
}

function generateClashConfig(siteUrl, userId, userName) {
  const proxyUrl = `${siteUrl}/.netlify/functions/proxy`;
  
  return `port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: true
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

proxies:
  - name: "${userName}"
    type: http
    server: ${siteUrl.replace('https://', '').replace('http://', '')}
    port: 443
    tls: true
    headers:
      X-User-ID: ${userId}

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "${userName}"
      - DIRECT

rules:
  - MATCH,Proxy
`;
}

function generateYamlConfig(siteUrl, userId, userName) {
  return {
    port: 7890,
    'socks-port': 7891,
    'mixed-port': 7892,
    'allow-lan': true,
    mode: 'rule',
    'log-level': 'info',
    'external-controller': '127.0.0.1:9090',
    proxies: [
      {
        name: userName,
        type: 'http',
        server: siteUrl.replace('https://', '').replace('http://', ''),
        port: 443,
        tls: true,
        headers: {
          'X-User-ID': userId
        }
      }
    ],
    'proxy-groups': [
      {
        name: 'Proxy',
        type: 'select',
        proxies: [userName, 'DIRECT']
      }
    ],
    rules: ['MATCH,Proxy']
  };
}

exports.handler = async (event, context) => {
  const store = await getStore(context);
  const method = event.httpMethod;
  const path = event.path.replace('/.netlify/functions/proxy', '').replace('/proxy', '');
  
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-ID',
    'Access-Control-Allow-Methods': 'GET, POST, CONNECT, OPTIONS'
  };
  
  if (method === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }
  
  if (method === 'GET' && path === '/config') {
    const userId = event.queryStringParameters?.user_id || event.headers['x-user-id'];
    
    if (!userId) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Missing user_id parameter' })
      };
    }
    
    const userConfig = await getUserConfig(store, userId);
    if (!userConfig) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ error: 'User not found' })
      };
    }
    
    const yamlConfig = generateYamlConfig(SITE_URL, userId, userConfig.name);
    
    return {
      statusCode: 200,
      headers: { ...headers, 'Content-Type': 'text/yaml' },
      body: generateClashConfig(SITE_URL, userId, userConfig.name)
    };
  }
  
  if (method === 'GET' && path === '/subscribe') {
    const userId = event.queryStringParameters?.user_id;
    
    if (!userId) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Missing user_id parameter' })
      };
    }
    
    const userConfig = await getUserConfig(store, userId);
    if (!userConfig) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ error: 'User not found' })
      };
    }
    
    const subscribeUrl = `${SITE_URL}/.netlify/functions/proxy/config?user_id=${userId}`;
    const base64Config = Buffer.from(generateClashConfig(SITE_URL, userId, userConfig.name)).toString('base64');
    
    return {
      statusCode: 200,
      headers: { ...headers, 'Content-Type': 'text/plain' },
      body: base64Config
    };
  }
  
  if (method === 'POST' && path === '/register') {
    const userId = generateUserId();
    const userName = `VPN-${userId.substring(0, 6)}`;
    
    await setUserConfig(store, userId, {
      id: userId,
      name: userName,
      createdAt: new Date().toISOString(),
      bytesUsed: 0
    });
    
    const clashConfig = generateClashConfig(SITE_URL, userId, userName);
    const subscribeUrl = `${SITE_URL}/.netlify/functions/proxy/subscribe?user_id=${userId}`;
    
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        userId,
        userName,
        subscribeUrl,
        configDownloadUrl: `${SITE_URL}/.netlify/functions/proxy/config?user_id=${userId}`,
        clashConfig
      })
    };
  }
  
  if (method === 'GET' || method === 'POST') {
    const userId = event.headers['x-user-id'] || event.queryStringParameters?.user_id;
    
    if (!userId) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Unauthorized - Missing X-User-ID header' })
      };
    }
    
    const userConfig = await getUserConfig(store, userId);
    if (!userConfig) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Unauthorized - Invalid user' })
      };
    }
    
    const usage = await getUsage(store);
    if (usage.bytes >= NETLIFY_FREE_BANDWIDTH) {
      return {
        statusCode: 429,
        headers,
        body: JSON.stringify({ 
          error: 'Monthly bandwidth limit exceeded',
          resetDate: getResetDate().toISOString()
        })
      };
    }
    
    let targetUrl = path.startsWith('/') ? path.slice(1) : path;
    
    if (!targetUrl) {
      targetUrl = event.queryStringParameters?.url;
    }
    
    if (!targetUrl) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'Missing target URL',
          usage: 'Use format: /proxy/https://example.com or ?url=https://example.com'
        })
      };
    }
    
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'https://' + targetUrl;
    }
    
    try {
      const requestHeaders = { ...event.headers };
      delete requestHeaders['host'];
      delete requestHeaders['content-length'];
      delete requestHeaders['x-user-id'];
      
      const response = await fetch(targetUrl, {
        method: method,
        headers: requestHeaders,
        body: method === 'POST' ? event.body : undefined,
        redirect: 'follow',
        timeout: 30000
      });
      
      const responseBody = await response.buffer();
      const responseSize = responseBody.length + JSON.stringify(requestHeaders).length;
      
      await updateUsage(store, responseSize);
      
      const responseHeaders = {};
      response.headers.forEach((value, key) => {
        if (key.toLowerCase() !== 'content-encoding' && 
            key.toLowerCase() !== 'transfer-encoding') {
          responseHeaders[key] = value;
        }
      });
      responseHeaders['X-Proxy-By'] = 'Netlify-VPN';
      
      const contentType = response.headers.get('content-type') || '';
      const isBinary = !contentType.includes('text/') && 
                       !contentType.includes('application/json') &&
                       !contentType.includes('application/javascript');
      
      return {
        statusCode: response.status,
        headers: responseHeaders,
        body: isBinary ? responseBody.toString('base64') : responseBody.toString('utf-8'),
        isBase64Encoded: isBinary
      };
    } catch (error) {
      console.error('Proxy error:', error);
      return {
        statusCode: 502,
        headers,
        body: JSON.stringify({ 
          error: 'Proxy request failed', 
          details: error.message
        })
      };
    }
  }
  
  return {
    statusCode: 405,
    headers,
    body: JSON.stringify({ error: 'Method not allowed' })
  };
};

exports.getUsage = getUsage;
exports.updateUsage = updateUsage;
exports.getStore = getStore;
exports.getUserConfig = getUserConfig;
exports.setUserConfig = setUserConfig;
exports.generateClashConfig = generateClashConfig;
exports.NETLIFY_FREE_BANDWIDTH = NETLIFY_FREE_BANDWIDTH;
exports.ADMIN_TOKEN = ADMIN_TOKEN;
exports.getResetDate = getResetDate;
exports.getMonthKey = getMonthKey;
exports.SITE_URL = SITE_URL;
