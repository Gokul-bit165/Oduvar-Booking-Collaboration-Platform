-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED', 'COMPLETED');

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN     "blocks_until" TIMESTAMP(3),
ADD COLUMN     "cancelled_at" TIMESTAMP(3),
ADD COLUMN     "completed_at" TIMESTAMP(3),
ADD COLUMN     "confirmed_at" TIMESTAMP(3),
ADD COLUMN     "currency" TEXT NOT NULL DEFAULT 'INR',
ADD COLUMN     "end_time" TEXT,
ADD COLUMN     "ends_at" TIMESTAMP(3),
ADD COLUMN     "oduvar_service_id" UUID,
ADD COLUMN     "rejected_at" TIMESTAMP(3),
ADD COLUMN     "service_amount" DECIMAL(10,2),
ADD COLUMN     "starts_at" TIMESTAMP(3),
ADD COLUMN     "status_reason" VARCHAR(500),
ADD COLUMN     "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
ADD COLUMN     "total_amount" DECIMAL(10,2),
ADD COLUMN     "total_amount_snapshot" DECIMAL(10,2),
ADD COLUMN     "transport_fee" DECIMAL(10,2);

-- Convert the legacy text status to the enum in place (no data loss; bookings were a stub until now).
ALTER TABLE "bookings" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "bookings" ALTER COLUMN "status" TYPE "BookingStatus" USING ("status"::"BookingStatus");
ALTER TABLE "bookings" ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "data" JSONB;

-- CreateIndex
CREATE INDEX "bookings_oduvar_id_date_status_idx" ON "bookings"("oduvar_id", "date", "status");

-- CreateIndex
CREATE INDEX "bookings_client_id_created_at_idx" ON "bookings"("client_id", "created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");


-- Database-level backstop against double booking: two CONFIRMED bookings for the same Oduvar can never
-- occupy overlapping time ranges [starts_at, blocks_until) where blocks_until = end + the Oduvar's buffer.
-- The application also serialises accept/confirm with a per-Oduvar advisory lock and re-checks availability
-- inside the transaction; this constraint guarantees the invariant even if that logic were bypassed.
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_no_overlapping_confirmed"
  EXCLUDE USING gist ("oduvar_id" WITH =, tsrange("starts_at", "blocks_until") WITH &&)
  WHERE ("status" = 'CONFIRMED' AND "starts_at" IS NOT NULL AND "blocks_until" IS NOT NULL);
