import posix from "./index";

test("spawn /bin/sleep and wait for it to finish and confirm the time", () => {
  const t0 = new Date().valueOf();
  const pid = posix?.posix_spawn?.(
    "/bin/sleep",
    null,
    null,
    ["/bin/sleep", "0.5"],
    {}
  );
  if (pid == null) {
    throw Error("pid must be a positive integer");
  }
  posix?.waitpid?.(pid, 0);
  const tm = new Date().valueOf() - t0;
  expect(tm > 400 && tm < 1000).toBe(true);
});
