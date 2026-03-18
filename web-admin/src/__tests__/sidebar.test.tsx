import "@testing-library/jest-dom";
import { render, screen } from "@testing-library/react";
import { Sidebar } from "@/components/sidebar";

jest.mock("next/navigation", () => ({
  usePathname: () => "/",
  useRouter: () => ({ push: jest.fn(), refresh: jest.fn() }),
}));
jest.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: { signOut: jest.fn().mockResolvedValue({}) },
  }),
}));
jest.mock("sonner", () => ({
  toast: { success: jest.fn() },
}));

describe("<Sidebar />", () => {
  it("renders navigation links", () => {
    render(<Sidebar />);
    expect(screen.getByText("Dashboard")).toBeInTheDocument();
    expect(screen.getByText("Users")).toBeInTheDocument();
    expect(screen.getByText("Games")).toBeInTheDocument();
    expect(screen.getByText("Claims")).toBeInTheDocument();
    expect(screen.getByText("Analytics")).toBeInTheDocument();
    expect(screen.getByText("Push")).toBeInTheDocument();
  });

  it("renders brand name", () => {
    render(<Sidebar />);
    expect(screen.getByText("Fish & Chips")).toBeInTheDocument();
    expect(screen.getByText("Admin Panel")).toBeInTheDocument();
  });

  it("renders Log out button", () => {
    render(<Sidebar />);
    expect(screen.getByRole("button", { name: /log out/i })).toBeInTheDocument();
  });

  it("does not show pending badge when count is 0", () => {
    render(<Sidebar pendingClaims={0} />);
    expect(screen.queryByText("0")).not.toBeInTheDocument();
  });

  it("shows pending badge when there are pending claims", () => {
    render(<Sidebar pendingClaims={5} />);
    expect(screen.getByText("5")).toBeInTheDocument();
  });

  it("highlights Dashboard link as active on /", () => {
    render(<Sidebar />);
    const dashboardLink = screen.getByRole("link", { name: /dashboard/i });
    expect(dashboardLink).toHaveClass("bg-primary");
  });
});
