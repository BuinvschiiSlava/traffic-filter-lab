CREATE TABLE IF NOT EXISTS lab_status (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component text NOT NULL UNIQUE,
    status text NOT NULL,
    checked_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO lab_status (component, status)
VALUES ('database', 'ready')
ON CONFLICT (component) DO UPDATE
SET status = EXCLUDED.status,
    checked_at = now();
