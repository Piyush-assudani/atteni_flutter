const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const DB_PATH = "artifacts/student-system-v2/public/data";

exports.aggregateAttendanceStats = functions.database
  .ref(`/${DB_PATH}/attendance/{date}/list/{studentId}`)
  .onWrite((change, context) => {
    const date = context.params.date;

    const beforeVal = change.before.val();
    const afterVal = change.after.val();

    if (beforeVal === afterVal) return null;

    const statsRef = admin.database().ref(`/${DB_PATH}/stats/${date}`);

    const isPresent = (val) =>
      ["P", "Present", true, "E", "Early"].includes(val) ||
      (typeof val === "string" && (val.toUpperCase().startsWith("P") || val.toUpperCase().startsWith("E")));

    const isAbsent = (val) =>
      ["A", "Absent", false].includes(val) ||
      (typeof val === "string" && val.toUpperCase().startsWith("A"));

    let pDiff = 0; let aDiff = 0;

    if (change.before.exists()) {
      if (isPresent(beforeVal)) pDiff -= 1;
      else if (isAbsent(beforeVal)) aDiff -= 1;
    }

    if (change.after.exists()) {
      if (isPresent(afterVal)) pDiff += 1;
      else if (isAbsent(afterVal)) aDiff += 1;
    }

    if (pDiff !== 0 || aDiff !== 0) {
      return statsRef.transaction((currentData) => {
        if (currentData === null) {
          return {
            presentCount: Math.max(0, pDiff),
            absentCount: Math.max(0, aDiff)
          };
        }
        currentData.presentCount = Math.max(0, (currentData.presentCount || 0) + pDiff);
        currentData.absentCount = Math.max(0, (currentData.absentCount || 0) + aDiff);
        return currentData;
      });
    }

    return null;
  });
