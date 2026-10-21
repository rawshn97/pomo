// Serverless focus session presence relay for cross-device sync.
// Allows mobile, macOS, and Web PWA clients linked to the same account
// to detect active focus sessions across devices in real time.

const activeSessions = new Map();

// Housekeeping: remove sessions older than 45 seconds
function pruneExpiredSessions() {
  const now = Date.now();
  for (const [key, session] of activeSessions.entries()) {
    if (now - session.updatedAt > 45000) {
      activeSessions.delete(key);
    }
  }
}

export default async function handler(req, res) {
  // CORS preflight handling
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  pruneExpiredSessions();

  try {
    const notionToken = process.env.NOTION_TOKEN || '';
    const accessToken = process.env.FOCUS_ACCESS_TOKEN || '';
    const rawAuth = req.headers.authorization || '';
    const bearer = rawAuth.replace(/^Bearer\s+/i, '').trim();

    let accountKey = '';
    if (!bearer) {
      return res.status(401).json({
        error: 'Access code required. Enter the focus access code to continue.',
      });
    } else if (accessToken && bearer === accessToken) {
      accountKey = 'focus_access_token_account';
    } else if (bearer.startsWith('secret_') || bearer.startsWith('ntn_')) {
      // Direct integration token: use hash or safe prefix
      accountKey = `notion_${bearer.slice(0, 16)}`;
    } else if (notionToken && bearer === notionToken) {
      accountKey = 'focus_access_token_account';
    } else {
      return res.status(401).json({
        error: 'Invalid access token.',
      });
    }

    if (req.method === 'GET') {
      const session = activeSessions.get(accountKey);
      if (session && session.status !== 'stopped') {
        const age = Date.now() - session.updatedAt;
        if (age <= 45000) {
          const elapsedSecs = Math.floor(age / 1000);
          const liveRemaining = session.status === 'running'
            ? Math.max(0, session.remainingSeconds - elapsedSecs)
            : session.remainingSeconds;

          return res.status(200).json({
            active: liveRemaining > 0,
            session: {
              ...session,
              remainingSeconds: liveRemaining,
            },
          });
        }
      }
      return res.status(200).json({ active: false });
    }

    if (req.method === 'POST') {
      const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
      const {
        deviceId,
        deviceName,
        status,
        lap,
        lapNumber,
        remainingSeconds,
        totalSeconds,
        tagName,
        tagIcon,
        taskTitle,
      } = body;

      if (status === 'stopped') {
        activeSessions.delete(accountKey);
        return res.status(200).json({ success: true, active: false });
      }

      const session = {
        deviceId: deviceId || 'unknown',
        deviceName: deviceName || 'Device',
        status: status || 'running',
        lap: lap || 'work',
        lapNumber: Number(lapNumber) || 1,
        remainingSeconds: Number(remainingSeconds) || 0,
        totalSeconds: Number(totalSeconds) || 0,
        tagName: tagName || null,
        tagIcon: tagIcon || null,
        taskTitle: taskTitle || null,
        updatedAt: Date.now(),
      };

      activeSessions.set(accountKey, session);
      return res.status(200).json({ success: true, active: true, session });
    }

    if (req.method === 'DELETE') {
      activeSessions.delete(accountKey);
      return res.status(200).json({ success: true, active: false });
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error('Session API Error:', error);
    return res.status(500).json({
      error: 'Internal Server Error handling session presence',
      details: error.message,
    });
  }
}
