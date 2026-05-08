import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import admin from "firebase-admin";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: "1mb" }));

// ────────────────────────────────────────────────────────────────────────
// FIREBASE ADMIN INIT
// ────────────────────────────────────────────────────────────────────────

let db = null;

try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON && !admin.apps.length) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    db = admin.firestore();
    console.log("Firebase Admin initialized");
  } else {
    console.log("FIREBASE_SERVICE_ACCOUNT_JSON missing. Firebase routes will not work.");
  }
} catch (error) {
  console.error("Firebase Admin init error:", error);
}

// ────────────────────────────────────────────────────────────────────────
// HEALTH CHECK
// ────────────────────────────────────────────────────────────────────────

app.get("/", (req, res) => {
  res.json({
    ok: true,
    message: "TimePilot backend running",
    firebaseReady: db !== null,
    mapsReady: Boolean(process.env.GOOGLE_MAPS_API_KEY),
  });
});

// ────────────────────────────────────────────────────────────────────────
// OPENCLAW LOCAL ASSISTANT
// ────────────────────────────────────────────────────────────────────────

function parseTimeTo24Hour(text) {
  const lower = text.toLowerCase();
  const match = lower.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/);

  if (!match) return null;

  let hour = parseInt(match[1], 10);
  const minute = match[2] ? parseInt(match[2], 10) : 0;
  const period = match[3];

  if (period === "pm" && hour < 12) hour += 12;
  if (period === "am" && hour === 12) hour = 0;

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return {
    hour,
    minute,
    timeLabel: `${hour.toString().padStart(2, "0")}:${minute
      .toString()
      .padStart(2, "0")}`,
  };
}

function extractActionFromMessage(message) {
  const lower = message.toLowerCase();
  const parsedTime = parseTimeTo24Hour(message);

  if (!parsedTime) return null;

  const isTask =
    lower.includes("remind me") ||
    lower.includes("reminder") ||
    lower.includes("add task") ||
    lower.includes("add work") ||
    lower.includes("schedule task");

  const isAlarm =
    lower.includes("set alarm") ||
    lower.includes("wake me") ||
    lower.includes("alarm for");

  if (isAlarm) {
    return {
      type: "create_alarm",
      title: "OpenClaw Alarm",
      time: parsedTime.timeLabel,
    };
  }

  if (isTask) {
    let title = message
      .replace(/remind me to/gi, "")
      .replace(/reminder/gi, "")
      .replace(/add task/gi, "")
      .replace(/add work/gi, "")
      .replace(/schedule task/gi, "")
      .replace(/at\s+\d{1,2}(:\d{2})?\s*(am|pm)?/gi, "")
      .trim();

    if (!title) title = "OpenClaw Task";

    return {
      type: "create_task",
      title,
      description: "Added by OpenClaw Chat",
      time: parsedTime.timeLabel,
    };
  }

  return null;
}

function getLocalReply(message, context = {}) {
  const lower = message.toLowerCase();

  if (lower.includes("time")) {
    return `It is ${context.currentDeviceTime?.label || "not available"} right now.`;
  }

  if (
    lower.includes("next") ||
    lower.includes("plan") ||
    lower.includes("task")
  ) {
    const next = context.nextUpcomingTask;

    if (next) {
      return `Your next task is "${next.title}" at ${next.timeLabel} ${
        next.dayLabel || ""
      }. ${next.suggestion ? next.suggestion : "Stay focused and complete it on time."}`;
    }

    return "I could not find an upcoming task. Add tasks in Planner first.";
  }

  if (
    lower.includes("screen") ||
    lower.includes("focus") ||
    lower.includes("productivity")
  ) {
    const p = context.productivity;

    if (p) {
      return `Your productivity score is ${p.score}/100. Distracted time is ${p.distractedMinutes} minutes and productive time is ${p.productiveMinutes} minutes.`;
    }

    return "Open the Focus tab and refresh screen-time data first.";
  }

  if (lower.includes("report") || lower.includes("day")) {
    const report = context.dailyReport;

    if (report?.summary) {
      return report.summary;
    }

    return "Generate your Daily Time Intelligence Report from the Dashboard first.";
  }

  if (lower.includes("alarm") || lower.includes("wake")) {
    const alarm = context.activeAlarm;

    if (alarm) {
      return `Your active alarm is set for ${alarm.activeTime}. Destination: ${
        alarm.destination || "not set"
      }.`;
    }

    return "No active alarm found. You can ask me: set alarm for 6:30 AM.";
  }

  return "I am OpenClaw, your TimePilot assistant. I can tell your next task, current time, productivity score, set reminders, and set alarms.";
}

app.post("/ask-openclaw", async (req, res) => {
  try {
    const { message, context } = req.body;

    if (!message) {
      return res.status(400).json({ error: "message is required" });
    }

    const detectedAction = extractActionFromMessage(message);

    if (detectedAction) {
      if (detectedAction.type === "create_task") {
        return res.json({
          reply: `Done. I added "${detectedAction.title}" at ${detectedAction.time} with reminder ON.`,
          action: detectedAction,
        });
      }

      if (detectedAction.type === "create_alarm") {
        return res.json({
          reply: `Done. I set an alarm for ${detectedAction.time}.`,
          action: detectedAction,
        });
      }
    }

    const reply = getLocalReply(message, context);
    return res.json({ reply });
  } catch (error) {
    console.error("OpenClaw backend error:", error);

    return res.json({
      reply:
        "OpenClaw fallback is active. I can still help with tasks, alarms, focus, and daily reports.",
    });
  }
});

// ────────────────────────────────────────────────────────────────────────
// GOOGLE MAPS TRAFFIC
// ────────────────────────────────────────────────────────────────────────

function parseDurationSeconds(value) {
  if (!value) return 0;

  if (typeof value === "string" && value.endsWith("s")) {
    return Number(value.replace("s", "")) || 0;
  }

  return Number(value) || 0;
}

async function getGoogleTraffic({ origin, destination, transportMode }) {
  if (!process.env.GOOGLE_MAPS_API_KEY) {
    throw new Error("GOOGLE_MAPS_API_KEY missing in Render environment variables");
  }

  const travelMode =
    transportMode?.toLowerCase() === "bus" ? "TRANSIT" : "DRIVE";

  const response = await fetch(
    "https://routes.googleapis.com/directions/v2:computeRoutes",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": process.env.GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask":
          "routes.duration,routes.staticDuration,routes.distanceMeters",
      },
      body: JSON.stringify({
        origin: { address: origin },
        destination: { address: destination },
        travelMode,
        routingPreference:
          travelMode === "DRIVE" ? "TRAFFIC_AWARE" : undefined,
        computeAlternativeRoutes: false,
        languageCode: "en-IN",
        units: "METRIC",
      }),
    }
  );

  const data = await response.json();

  if (!response.ok) {
    throw new Error(JSON.stringify(data));
  }

  const route = data.routes?.[0];

  if (!route) {
    throw new Error("No route found");
  }

  const trafficDurationSeconds = parseDurationSeconds(route.duration);
  const normalDurationSeconds = parseDurationSeconds(route.staticDuration);

  const trafficDurationMinutes = Math.ceil(trafficDurationSeconds / 60);
  const normalDurationMinutes = Math.ceil(normalDurationSeconds / 60);

  const extraDelayMinutes = Math.max(
    0,
    trafficDurationMinutes - normalDurationMinutes
  );

  return {
    normalDurationMinutes,
    trafficDurationMinutes,
    extraDelayMinutes,
    shouldReschedule: extraDelayMinutes >= 5,
    distanceMeters: route.distanceMeters || 0,
  };
}

app.post("/check-traffic", async (req, res) => {
  try {
    const { origin, destination, transportMode } = req.body;

    if (!origin || !destination) {
      return res.status(400).json({
        error: "origin and destination are required",
      });
    }

    const traffic = await getGoogleTraffic({
      origin,
      destination,
      transportMode,
    });

    return res.json({
      origin,
      destination,
      transportMode,
      ...traffic,
      message:
        traffic.extraDelayMinutes >= 5
          ? `Traffic is heavier by ${traffic.extraDelayMinutes} minutes.`
          : "Traffic is normal.",
    });
  } catch (error) {
    console.error("Traffic check error:", error);

    return res.status(500).json({
      error: "Traffic check failed",
      details: error.message,
    });
  }
});

// ────────────────────────────────────────────────────────────────────────
// SAVE USER ROUTINE FOR AUTOMATIC TRAFFIC WATCH
// ────────────────────────────────────────────────────────────────────────

app.post("/save-user-routine", async (req, res) => {
  try {
    if (!db) {
      return res.status(500).json({
        error: "Firebase Admin / Firestore is not initialized",
      });
    }

    const {
      deviceId,
      fcmToken,
      userType,
      origin,
      destination,
      transportMode,
      wakeHour,
      wakeMinute,
      arrivalHour,
      arrivalMinute,
      dailyRoutine,
      autoTrafficWatch,
    } = req.body;

    if (!deviceId || !fcmToken || !origin || !destination) {
      return res.status(400).json({
        error: "deviceId, fcmToken, origin, and destination are required",
      });
    }

    await db.collection("user_routines").doc(deviceId).set(
      {
        deviceId,
        fcmToken,
        userType: userType || "Student",
        origin,
        destination,
        transportMode: transportMode || "car",
        wakeHour: Number(wakeHour ?? 7),
        wakeMinute: Number(wakeMinute ?? 0),
        arrivalHour: Number(arrivalHour ?? 9),
        arrivalMinute: Number(arrivalMinute ?? 0),
        dailyRoutine: dailyRoutine || "",
        autoTrafficWatch: autoTrafficWatch === true,
        lastTrafficCheckDate: "",
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    return res.json({
      ok: true,
      message: "Routine saved for automatic traffic watch",
    });
  } catch (error) {
    console.error("Save routine error:", error);

    return res.status(500).json({
      error: "Failed to save routine",
      details: error.message,
    });
  }
});

// ────────────────────────────────────────────────────────────────────────
// CRON: CHECK ALARMS ONE HOUR BEFORE WAKE TIME
// ────────────────────────────────────────────────────────────────────────

function formatTime(date) {
  return date.toLocaleTimeString("en-IN", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
    timeZone: "Asia/Kolkata",
  });
}

app.post("/cron/check-alarms", async (req, res) => {
  try {
    const secret = req.headers["x-cron-secret"];

    if (secret !== process.env.CRON_SECRET) {
      return res.status(401).json({
        error: "Unauthorized cron request",
      });
    }

    if (!db) {
      return res.status(500).json({
        error: "Firebase Admin / Firestore is not initialized",
      });
    }

    const force = req.body?.force === true;

    // Current time in India
    const now = new Date();
    const indiaNowString = now.toLocaleString("en-US", {
      timeZone: "Asia/Kolkata",
    });
    const indiaNow = new Date(indiaNowString);

    const todayKey = `${indiaNow.getFullYear()}-${String(
      indiaNow.getMonth() + 1
    ).padStart(2, "0")}-${String(indiaNow.getDate()).padStart(2, "0")}`;

    const nowMinutes = indiaNow.getHours() * 60 + indiaNow.getMinutes();

    const snapshot = await db
      .collection("user_routines")
      .where("autoTrafficWatch", "==", true)
      .get();

    let checked = 0;
    let notified = 0;
    const results = [];

    for (const doc of snapshot.docs) {
      const user = doc.data();

      const wakeHour = Number(user.wakeHour);
      const wakeMinute = Number(user.wakeMinute);

      if (
        Number.isNaN(wakeHour) ||
        Number.isNaN(wakeMinute) ||
        !user.origin ||
        !user.destination
      ) {
        results.push({
          user: user.userType || "Unknown",
          status: "skipped",
          reason: "Invalid saved routine data",
        });
        continue;
      }

      const wakeMinutes = wakeHour * 60 + wakeMinute;

      // Traffic check should happen 1 hour before wake-up.
      let trafficCheckMinutes = wakeMinutes - 60;

      // Handle midnight case.
      if (trafficCheckMinutes < 0) {
        trafficCheckMinutes += 24 * 60;
      }

      let diffMinutes = Math.abs(nowMinutes - trafficCheckMinutes);

      // Handle day-boundary wraparound.
      diffMinutes = Math.min(diffMinutes, 24 * 60 - diffMinutes);

      if (!force && user.lastTrafficCheckDate === todayKey) {
        results.push({
          user: user.userType || "Unknown",
          status: "skipped",
          reason: "Already checked today",
          nowMinutes,
          wakeMinutes,
          trafficCheckMinutes,
          diffMinutes,
        });
        continue;
      }

      // IMPORTANT:
      // Cloud Scheduler runs every 7 minutes.
      // So we allow a 15-minute window to avoid missing the check.
      if (!force && diffMinutes > 15) {
        results.push({
          user: user.userType || "Unknown",
          status: "skipped",
          reason: "Not inside 1-hour-before check window",
          nowMinutes,
          wakeMinutes,
          trafficCheckMinutes,
          diffMinutes,
        });
        continue;
      }

      checked++;

      const traffic = await getGoogleTraffic({
        origin: user.origin,
        destination: user.destination,
        transportMode: user.transportMode,
      });

      await doc.ref.update({
        lastTrafficCheckDate: todayKey,
        lastTrafficResult: traffic,
        lastTrafficCheckedAt: new Date().toISOString(),
      });

      let fcmStatus = "not_sent";

      if (traffic.extraDelayMinutes >= 5 && user.fcmToken) {
  let adjustedWakeMinutes = wakeMinutes - traffic.extraDelayMinutes;

  if (adjustedWakeMinutes < 0) {
    adjustedWakeMinutes += 24 * 60;
  }

  const adjustedHour = Math.floor(adjustedWakeMinutes / 60);
  const adjustedMinute = adjustedWakeMinutes % 60;

  const newWakeLabel = `${String(adjustedHour).padStart(2, "0")}:${String(
    adjustedMinute
  ).padStart(2, "0")}`;

  try {
    const messageId = await admin.messaging().send({
      token: user.fcmToken,
      notification: {
        title: "TimePilot adjusted your alarm",
        body: `Traffic is +${traffic.extraDelayMinutes} min. Wake up at ${newWakeLabel}.`,
      },
      data: {
        type: "traffic_alarm_shift",
        extraDelayMinutes: String(traffic.extraDelayMinutes),
        newWakeLabel,
        normalDurationMinutes: String(traffic.normalDurationMinutes),
        trafficDurationMinutes: String(traffic.trafficDurationMinutes),
        origin: user.origin,
        destination: user.destination,
      },
      android: {
        priority: "high",
      },
    });

    notified++;
    fcmStatus = "sent";

    results.push({
      user: user.userType || "Unknown",
      status: "notification_sent",
      messageId,
      newWakeLabel,
    });
  } catch (fcmError) {
    console.error("FCM send failed:", fcmError);

    fcmStatus = "failed";

    // If token is invalid/deleted, remove it so future cron does not keep failing.
    await doc.ref.update({
      fcmTokenInvalid: true,
      fcmError: fcmError.message,
      fcmFailedAt: new Date().toISOString(),
    });

    results.push({
      user: user.userType || "Unknown",
      status: "traffic_checked_but_fcm_failed",
      reason: fcmError.message,
      newWakeLabel,
      traffic,
    });
  }
}

      results.push({
        user: user.userType || "Unknown",
        status: "checked",
        origin: user.origin,
        destination: user.destination,
        wakeHour: user.wakeHour,
        wakeMinute: user.wakeMinute,
        traffic,
        fcmStatus,
      });
    }

    return res.json({
      ok: true,
      force,
      checked,
      notified,
      totalUsers: snapshot.size,
      indiaTime: `${String(indiaNow.getHours()).padStart(2, "0")}:${String(
        indiaNow.getMinutes()
      ).padStart(2, "0")}`,
      schedulerInterval: "7 minutes",
      allowedWindowMinutes: 15,
      results,
    });
  } catch (error) {
    console.error("Cron alarm check error:", error);

    return res.status(500).json({
      error: "Cron alarm check failed",
      details: error.message,
    });
  }
});

// ────────────────────────────────────────────────────────────────────────
// START SERVER
// ────────────────────────────────────────────────────────────────────────

app.listen(port, () => {
  console.log(`TimePilot backend running on port ${port}`);
});