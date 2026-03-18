import "@testing-library/jest-dom";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { UserForm } from "@/app/(admin)/users/[id]/user-form";
import type { Profile } from "@/types/database";

jest.mock("@/app/(admin)/users/[id]/actions", () => ({
  updateUserProfile: jest.fn(),
  deleteUserAccount: jest.fn(),
}));
jest.mock("next/navigation", () => ({
  useRouter: () => ({ push: jest.fn() }),
}));
jest.mock("sonner", () => ({
  toast: { success: jest.fn(), error: jest.fn() },
}));

const { updateUserProfile, deleteUserAccount } = jest.requireMock(
  "@/app/(admin)/users/[id]/actions"
);
const { toast } = jest.requireMock("sonner");

const mockProfile: Profile = {
  id: "user-1",
  username: "testuser",
  display_name: "Test User",
  is_anonymous: false,
  is_public: true,
  is_super_admin: false,
  subscription_status: "free",
  subscription_expires_at: null,
  total_games_played: 5,
  total_buyins: 10000,
  total_cashouts: 12000,
  created_at: "2024-01-01T00:00:00Z",
  last_login_at: null,
  updated_at: null,
};

describe("<UserForm />", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("renders Save Changes button", () => {
    render(<UserForm profile={mockProfile} />);
    expect(
      screen.getByRole("button", { name: /save changes/i })
    ).toBeInTheDocument();
  });

  it("renders at least 2 buttons (Save + Delete)", () => {
    render(<UserForm profile={mockProfile} />);
    expect(screen.getAllByRole("button").length).toBeGreaterThanOrEqual(2);
  });

  it("calls updateUserProfile on Save", async () => {
    updateUserProfile.mockResolvedValue(undefined);
    render(<UserForm profile={mockProfile} />);

    fireEvent.click(screen.getByRole("button", { name: /save changes/i }));

    await waitFor(() => {
      expect(updateUserProfile).toHaveBeenCalledWith("user-1", {
        is_super_admin: false,
        is_public: true,
        subscription_status: "free",
      });
    });
    expect(toast.success).toHaveBeenCalledWith("Profile updated");
  });

  it("shows error toast when save fails", async () => {
    updateUserProfile.mockRejectedValue(new Error("Save failed"));
    render(<UserForm profile={mockProfile} />);

    fireEvent.click(screen.getByRole("button", { name: /save changes/i }));

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalledWith("Error: Save failed");
    });
  });

  it("opens delete dialog by clicking the icon button (last button)", async () => {
    render(<UserForm profile={mockProfile} />);
    const buttons = screen.getAllByRole("button");
    // Last button in the flex row is the trash/delete button
    const deleteIconButton = buttons[buttons.length - 1];
    fireEvent.click(deleteIconButton);

    await waitFor(() => {
      expect(screen.getAllByText(/delete account/i).length).toBeGreaterThan(0);
    });
  });

  it("calls deleteUserAccount on confirm delete", async () => {
    deleteUserAccount.mockResolvedValue(undefined);
    render(<UserForm profile={mockProfile} />);

    // Open dialog
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[buttons.length - 1]);

    await waitFor(() =>
      expect(
        screen.getAllByRole("button", { name: /delete account/i }).length
      ).toBeGreaterThan(0)
    );

    const confirmButtons = screen.getAllByRole("button", {
      name: /delete account/i,
    });
    fireEvent.click(confirmButtons[confirmButtons.length - 1]);

    await waitFor(() => {
      expect(deleteUserAccount).toHaveBeenCalledWith("user-1");
    });
    expect(toast.success).toHaveBeenCalledWith("Account deleted");
  });

  it("initializes Super Admin switch from profile value (false)", () => {
    render(<UserForm profile={{ ...mockProfile, is_super_admin: false }} />);
    const switches = screen.getAllByRole("switch");
    expect(switches[0]).not.toBeChecked();
  });

  it("initializes Public switch from profile value (true)", () => {
    render(<UserForm profile={{ ...mockProfile, is_public: true }} />);
    const switches = screen.getAllByRole("switch");
    // second switch is is_public
    expect(switches[1]).toBeChecked();
  });
});
