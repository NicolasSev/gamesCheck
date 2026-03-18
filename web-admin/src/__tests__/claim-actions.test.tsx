import "@testing-library/jest-dom";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { ClaimActions } from "@/app/(admin)/claims/claim-actions";

jest.mock("@/app/(admin)/claims/actions", () => ({
  updateClaimStatus: jest.fn(),
}));
jest.mock("sonner", () => ({
  toast: { success: jest.fn(), error: jest.fn() },
}));

const { updateClaimStatus } = jest.requireMock("@/app/(admin)/claims/actions");
const { toast } = jest.requireMock("sonner");

describe("<ClaimActions />", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("renders nothing when status is not pending", () => {
    const { container } = render(
      <ClaimActions claimId="abc" status="approved" />
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing for rejected status", () => {
    const { container } = render(
      <ClaimActions claimId="abc" status="rejected" />
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders two buttons for pending status", () => {
    render(<ClaimActions claimId="abc" status="pending" />);
    expect(screen.getAllByRole("button")).toHaveLength(2);
  });

  it("calls updateClaimStatus with approved on first button click", async () => {
    updateClaimStatus.mockResolvedValue(undefined);
    render(<ClaimActions claimId="claim-1" status="pending" />);

    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[0]);

    await waitFor(() => {
      expect(updateClaimStatus).toHaveBeenCalledWith("claim-1", "approved");
    });
    expect(toast.success).toHaveBeenCalledWith("Claim approved");
  });

  it("calls updateClaimStatus with rejected on second button click", async () => {
    updateClaimStatus.mockResolvedValue(undefined);
    render(<ClaimActions claimId="claim-2" status="pending" />);

    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[1]);

    await waitFor(() => {
      expect(updateClaimStatus).toHaveBeenCalledWith("claim-2", "rejected");
    });
    expect(toast.success).toHaveBeenCalledWith("Claim rejected");
  });

  it("shows error toast when action fails", async () => {
    updateClaimStatus.mockRejectedValue(new Error("Server error"));
    render(<ClaimActions claimId="claim-3" status="pending" />);

    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[0]);

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalledWith("Error: Server error");
    });
  });

  it("disables buttons while loading", async () => {
    let resolve: () => void;
    updateClaimStatus.mockImplementation(
      () =>
        new Promise<void>((res) => {
          resolve = res;
        })
    );

    render(<ClaimActions claimId="claim-4" status="pending" />);
    const buttons = screen.getAllByRole("button");

    fireEvent.click(buttons[0]);

    await waitFor(() => {
      expect(buttons[0]).toBeDisabled();
      expect(buttons[1]).toBeDisabled();
    });

    resolve!();
    await waitFor(() => {
      expect(buttons[0]).not.toBeDisabled();
    });
  });
});
