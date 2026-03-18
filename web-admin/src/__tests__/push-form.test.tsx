import "@testing-library/jest-dom";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PushForm } from "@/app/(admin)/push/push-form";

jest.mock("@/app/(admin)/push/actions", () => ({
  sendPushNotification: jest.fn(),
}));
jest.mock("sonner", () => ({
  toast: { success: jest.fn(), error: jest.fn() },
}));

const { sendPushNotification } = jest.requireMock("@/app/(admin)/push/actions");
const { toast } = jest.requireMock("sonner");

describe("<PushForm />", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("shows device count", () => {
    render(<PushForm deviceCount={42} />);
    expect(screen.getByText(/42 devices registered/)).toBeInTheDocument();
  });

  it("shows singular 'device' for count=1", () => {
    render(<PushForm deviceCount={1} />);
    expect(screen.getByText(/1 device registered/)).toBeInTheDocument();
  });

  it("send button is disabled when fields are empty", () => {
    render(<PushForm deviceCount={5} />);
    expect(screen.getByRole("button", { name: /send/i })).toBeDisabled();
  });

  it("shows error toast when trying to send without title", async () => {
    render(<PushForm deviceCount={5} />);
    const button = screen.getByRole("button", { name: /send/i });

    fireEvent.click(button);
    expect(toast.error).not.toHaveBeenCalled();
  });

  it("shows preview when title is typed", async () => {
    render(<PushForm deviceCount={5} />);
    const titleInput = screen.getByPlaceholderText("Notification title");

    await userEvent.type(titleInput, "Hello");
    expect(screen.getByText("Hello")).toBeInTheDocument();
  });

  it("calls sendPushNotification with correct args", async () => {
    sendPushNotification.mockResolvedValue({ success: true, sent: 5 });
    render(<PushForm deviceCount={5} />);

    await userEvent.type(
      screen.getByPlaceholderText("Notification title"),
      "Test Title"
    );
    await userEvent.type(
      screen.getByPlaceholderText("Notification body"),
      "Test Body"
    );

    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(sendPushNotification).toHaveBeenCalledWith(
        "Test Title",
        "Test Body",
        "all",
        undefined
      );
    });
  });

  it("shows success toast and clears fields after send", async () => {
    sendPushNotification.mockResolvedValue({ success: true, sent: 10 });
    render(<PushForm deviceCount={10} />);

    const titleInput = screen.getByPlaceholderText("Notification title");
    const bodyInput = screen.getByPlaceholderText("Notification body");

    await userEvent.type(titleInput, "My Title");
    await userEvent.type(bodyInput, "My Body");

    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(toast.success).toHaveBeenCalledWith("Push sent to 10 devices");
    });

    expect((titleInput as HTMLInputElement).value).toBe("");
    expect((bodyInput as HTMLInputElement).value).toBe("");
  });

  it("shows error toast on failed send", async () => {
    sendPushNotification.mockResolvedValue({
      success: false,
      sent: 0,
      error: "No tokens",
    });
    render(<PushForm deviceCount={0} />);

    await userEvent.type(
      screen.getByPlaceholderText("Notification title"),
      "Title"
    );
    await userEvent.type(
      screen.getByPlaceholderText("Notification body"),
      "Body"
    );

    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalledWith("No tokens");
    });
  });

  it("adds to history after successful send", async () => {
    sendPushNotification.mockResolvedValue({ success: true, sent: 3 });
    render(<PushForm deviceCount={3} />);

    await userEvent.type(
      screen.getByPlaceholderText("Notification title"),
      "Hist Title"
    );
    await userEvent.type(
      screen.getByPlaceholderText("Notification body"),
      "Hist Body"
    );

    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(screen.getByText("Send History (this session)")).toBeInTheDocument();
    });
    expect(screen.getByText("Hist Title")).toBeInTheDocument();
  });
});
