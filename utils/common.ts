export const tryRun = async (fn: () => Promise<any>) => {
  try {
    return await fn();
  } catch (ex) {
    console.error(ex);
  }
};
