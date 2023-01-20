SET check_function_bodies = false;
CREATE FUNCTION public.add_monotonic_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
nextval bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(1);
  select nextval('serial_chats') into nextval;
  NEW.id := nextval;
  RETURN NEW;
END;
$$;
CREATE TABLE public.conversation_status (
    value text NOT NULL,
    comment text NOT NULL
);
CREATE TABLE public.conversation_users (
    conversation_id integer NOT NULL,
    user_id integer NOT NULL,
    status text
);
CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
CREATE TABLE public.messages (
    id integer DEFAULT nextval('public.messages_id_seq'::regclass) NOT NULL,
    message text NOT NULL,
    author_id integer NOT NULL,
    conversation_id integer NOT NULL
);
CREATE SEQUENCE public.serial_chats
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
CREATE TABLE public."user" (
    id integer NOT NULL,
    username text NOT NULL,
    last_typed timestamp with time zone,
    last_seen timestamp with time zone
);
COMMENT ON TABLE public."user" IS 'This table stores user data';
CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;
CREATE VIEW public.user_online AS
 SELECT "user".id,
    "user".username,
    "user".last_typed,
    "user".last_seen
   FROM public."user"
  WHERE ("user".last_seen > (now() - '00:00:10'::interval));
CREATE VIEW public.user_typing AS
 SELECT "user".id,
    "user".username,
    "user".last_typed,
    "user".last_seen
   FROM public."user"
  WHERE ("user".last_typed > (now() - '00:00:02'::interval));
ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);
ALTER TABLE ONLY public.conversation_users
    ADD CONSTRAINT channel_users_pkey PRIMARY KEY (conversation_id, user_id);
ALTER TABLE ONLY public.conversation_status
    ADD CONSTRAINT conversation_status_pkey PRIMARY KEY (value);
ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);
CREATE TRIGGER add_monotonic_id_trigger BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.add_monotonic_id();
ALTER TABLE ONLY public.conversation_users
    ADD CONSTRAINT channel_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY public.conversation_users
    ADD CONSTRAINT conversation_users_status_fkey FOREIGN KEY (status) REFERENCES public.conversation_status(value) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_author_id_fkey FOREIGN KEY (author_id) REFERENCES public."user"(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
