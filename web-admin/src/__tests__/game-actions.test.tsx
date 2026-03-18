import "@testing-library/jest-dom";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { GameActions } from "@/app/(admin)/games/[id]/game-actions";

jest.mock("@/app/(admin)/games/[id]/actions", () => ({
  toggleSoftDelete: jest.fn(),
}));
jest.mock("sonner", () => ({
  toast: { success: jest.fn(), error: jest.fn() },
}));

const { toggleSoftDelete } = jest.requireMock(
  "@/app/(admin)/games/[id]/actions"
);
const { toast } = jest.requireMock("sonner");

describe("<GameActions />", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("shows 'Soft Delete' when game is not deleted", () => {
    render(<GameActions gameId="g1" softDeleted={false} />);
    expect(screen.getByText("Soft Delete")).toBeInTheDocument();
  });

  it("shows 'Restore' when game is soft-deleted", () => {
    render(<GameActions gameId="g1" softDeleted={true} />);
    expect(screen.getByText("Restore")).toBeInTheDocument();
  });

  it("uses outline variant for restored (deleted) game", () => {
    render(<GameActions gameId="g1" softDeleted={true} />);
    const button = screen.getByRole("button");
    // Outline variant does not have bg-destructive
    const classList = button.className;
    expect(classList).not.toMatch(/bg-destructive/);
  });

  it("calls toggleSoftDelete with correct args on click", async () => {
    toggleSoftDelete.mockResolvedValue(undefined);
    render(<GameActions gameId="game-1" softDeleted={false} />);

    fireEvent.click(screen.getByRole("button"));

    await waitFor(() => {
      expect(toggleSoftDelete).toHaveBeenCalledWith("game-1", false);
    });
    expect(toast.success).toHaveBeenCalledWith("Game deleted");
  });

  it("shows 'Game restored' toast when restoring", async () => {
    toggleSoftDelete.mockResolvedValue(undefined);
    render(<GameActions gameId="game-2" softDeleted={true} />);

    fireEvent.click(screen.getByRole("button"));

    await waitFor(() => {
      expect(toast.success).toHaveBeenCalledWith("Game restored");
    });
  });

  it("shows error toast on failure", async () => {
    toggleSoftDelete.mockRejectedValue(new Error("DB error"));
    render(<GameActions gameId="game-3" softDeleted={false} />);

    fireEvent.click(screen.getByRole("button"));

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalledWith("Error: DB error");
    });
  });

  it("disables button during loading", async () => {
    let resolve: () => void;
    toggleSoftDelete.mockImplementation(
      () =>
        new Promise<void>((res) => {
          resolve = res;
        })
    );

    render(<GameActions gameId="game-4" softDeleted={false} />);
    const button = screen.getByRole("button");

    fireEvent.click(button);

    await waitFor(() => expect(button).toBeDisabled());

    resolve!();
    await waitFor(() => expect(button).not.toBeDisabled());
  });
});
