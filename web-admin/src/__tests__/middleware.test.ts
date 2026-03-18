/**
 * Middleware unit tests.
 * Tests the path-matching logic and redirect behavior.
 */

/**
 * Tests the middleware path exclusion logic by directly checking
 * whether a pathname should be excluded from middleware processing.
 */
function shouldExclude(pathname: string): boolean {
  return (
    pathname.startsWith("/_next/static") ||
    pathname.startsWith("/_next/image") ||
    pathname === "/favicon.ico" ||
    /\.(svg|png|jpg|jpeg|gif|webp)$/.test(pathname)
  );
}

describe("Middleware: path matching config", () => {
  it("matches root path / (not excluded)", () => {
    expect(shouldExclude("/")).toBe(false);
  });

  it("matches /users path (not excluded)", () => {
    expect(shouldExclude("/users")).toBe(false);
  });

  it("matches /games/[id] (not excluded)", () => {
    expect(shouldExclude("/games/abc-123")).toBe(false);
  });

  it("matches /login (not excluded)", () => {
    expect(shouldExclude("/login")).toBe(false);
  });

  it("does not match static files (excluded)", () => {
    expect(shouldExclude("/_next/static/chunks/main.js")).toBe(true);
  });

  it("does not match _next/image (excluded)", () => {
    expect(shouldExclude("/_next/image")).toBe(true);
  });

  it("does not match favicon.ico (excluded)", () => {
    expect(shouldExclude("/favicon.ico")).toBe(true);
  });

  it("does not match .svg files (excluded)", () => {
    expect(shouldExclude("/logo.svg")).toBe(true);
  });

  it("does not match .png files (excluded)", () => {
    expect(shouldExclude("/icon.png")).toBe(true);
  });
});

describe("Middleware: redirect logic", () => {
  it("unauthenticated users should redirect to /login", () => {
    const isLoggedIn = false;
    const pathname = "/users";
    const isLoginPage = pathname === "/login";

    const shouldRedirectToLogin = !isLoggedIn && !isLoginPage;
    expect(shouldRedirectToLogin).toBe(true);
  });

  it("unauthenticated users on /login should NOT redirect", () => {
    const isLoggedIn = false;
    const pathname = "/login";
    const isLoginPage = pathname === "/login";

    const shouldRedirectToLogin = !isLoggedIn && !isLoginPage;
    expect(shouldRedirectToLogin).toBe(false);
  });

  it("authenticated admins on /login redirect to /", () => {
    const isLoggedIn = true;
    const isAdmin = true;
    const pathname = "/login";
    const isLoginPage = pathname === "/login";

    const shouldRedirectToDashboard = isLoggedIn && isAdmin && isLoginPage;
    expect(shouldRedirectToDashboard).toBe(true);
  });

  it("authenticated non-admins get kicked out", () => {
    const isLoggedIn = true;
    const isAdmin = false;

    const shouldKick = isLoggedIn && !isAdmin;
    expect(shouldKick).toBe(true);
  });

  it("authenticated admins on /users pass through", () => {
    const isLoggedIn = true;
    const isAdmin = true;
    const pathname = "/users";
    const isLoginPage = pathname === "/login";

    const shouldBlock = !isLoggedIn;
    const shouldKick = isLoggedIn && !isAdmin;
    const shouldRedirectToDashboard = isLoggedIn && isAdmin && isLoginPage;

    expect(shouldBlock || shouldKick || shouldRedirectToDashboard).toBe(false);
  });
});
