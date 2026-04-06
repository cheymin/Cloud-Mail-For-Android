const { 
  getUsage, 
  getStore,
  NETLIFY_FREE_BANDWIDTH, 
  getResetDate, 
  getMonthKey 
} = require('./proxy');

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(date) {
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

function getDaysUntilReset() {
  const now = new Date();
  const reset = getResetDate();
  const diff = reset - now;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, OPTIONS'
};

exports.handler = async (event, context) => {
  const store = await getStore(context);
  const method = event.httpMethod;
  const path = event.path.replace('/.netlify/functions/admin', '').replace('/api/admin', '');
  
  if (method === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }
  
  try {
    if (path === '/stats' && method === 'GET') {
      const usage = await getUsage(store);
      const remaining = Math.max(0, NETLIFY_FREE_BANDWIDTH - usage.bytes);
      const percentage = ((usage.bytes / NETLIFY_FREE_BANDWIDTH) * 100).toFixed(2);
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          used: usage.bytes,
          usedFormatted: formatBytes(usage.bytes),
          remaining: remaining,
          remainingFormatted: formatBytes(remaining),
          total: NETLIFY_FREE_BANDWIDTH,
          totalFormatted: formatBytes(NETLIFY_FREE_BANDWIDTH),
          percentage: parseFloat(percentage),
          requests: usage.requests,
          resetDate: getResetDate().toISOString(),
          resetDateFormatted: formatDate(getResetDate()),
          daysUntilReset: getDaysUntilReset(),
          monthKey: getMonthKey()
        })
      };
    }
    
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Not found', path })
    };
  } catch (error) {
    console.error('Admin API error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: error.message })
    };
  }
};
