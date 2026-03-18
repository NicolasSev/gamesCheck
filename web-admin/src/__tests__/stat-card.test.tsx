import "@testing-library/jest-dom";
import { render, screen } from "@testing-library/react";
import { StatCard } from "@/components/stat-card";
import { Users } from "lucide-react";

describe("<StatCard />", () => {
  it("renders title and value", () => {
    render(<StatCard title="Total Users" value={42} icon={Users} />);
    expect(screen.getByText("Total Users")).toBeInTheDocument();
    expect(screen.getByText("42")).toBeInTheDocument();
  });

  it("renders string value", () => {
    render(<StatCard title="Volume" value="1,234 ₸" icon={Users} />);
    expect(screen.getByText("1,234 ₸")).toBeInTheDocument();
  });

  it("renders subtitle when provided", () => {
    render(
      <StatCard title="Games" value={10} icon={Users} sub="+3 this week" />
    );
    expect(screen.getByText("+3 this week")).toBeInTheDocument();
  });

  it("does not render subtitle when not provided", () => {
    render(<StatCard title="Games" value={10} icon={Users} />);
    expect(screen.queryByText(/this week/)).not.toBeInTheDocument();
  });

  it("applies green class for trend=up", () => {
    render(
      <StatCard
        title="Users"
        value={5}
        icon={Users}
        sub="growing"
        trend="up"
      />
    );
    const sub = screen.getByText("growing");
    expect(sub).toHaveClass("text-green-500");
  });

  it("applies red class for trend=down", () => {
    render(
      <StatCard
        title="Users"
        value={5}
        icon={Users}
        sub="declining"
        trend="down"
      />
    );
    const sub = screen.getByText("declining");
    expect(sub).toHaveClass("text-red-500");
  });

  it("applies muted class for trend=neutral", () => {
    render(
      <StatCard
        title="Users"
        value={5}
        icon={Users}
        sub="stable"
        trend="neutral"
      />
    );
    const sub = screen.getByText("stable");
    expect(sub).toHaveClass("text-muted-foreground");
  });

  it("applies muted class when no trend specified", () => {
    render(
      <StatCard title="Users" value={5} icon={Users} sub="no trend" />
    );
    const sub = screen.getByText("no trend");
    expect(sub).toHaveClass("text-muted-foreground");
  });
});
