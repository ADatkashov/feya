package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

/** Not transactional: it needs real DDL on a scratch schema. */
@SpringBootTest
@ActiveProfiles("test")
@org.springframework.context.annotation.Import(app.feya.support.TestClockConfig.class)
class MigrationIT {
    @Autowired DataSource dataSource;
    @Autowired Flyway flyway;
    @Autowired JdbcTemplate jdbc;

    @Test
    void allMigrationsAppliedSuccessfully() {
        var applied = flyway.info().applied();
        assertThat(applied).isNotEmpty();
        assertThat(applied).allSatisfy(m -> assertThat(m.getState().isApplied()).isTrue());
        assertThat(flyway.info().pending()).isEmpty();
    }

    @Test
    void productionMigrationsAloneBuildTheSchemaWithoutAnySeedData() {
        // Only the versioned (production) migrations, applied to an empty schema: no seed rows must appear.
        jdbc.execute("drop schema if exists migration_check cascade");
        jdbc.execute("create schema migration_check");
        try {
            Flyway f = Flyway.configure().dataSource(dataSource).schemas("migration_check").locations("classpath:db/migration")
                    .defaultSchema("migration_check").load();
            f.migrate();
            assertThat(f.info().current().getVersion().getVersion()).isEqualTo("1");
            Integer tables = jdbc.queryForObject("select count(*) from information_schema.tables where table_schema='migration_check' and table_type='BASE TABLE'", Integer.class);
            assertThat(tables).isGreaterThan(25);
            assertThat(jdbc.queryForObject("select count(*) from migration_check.products", Integer.class)).isZero();
            assertThat(jdbc.queryForObject("select count(*) from migration_check.users", Integer.class)).isZero();
        } finally {
            jdbc.execute("drop schema migration_check cascade");
        }
    }

    @Test
    void importantConstraintsExist() {
        // One pending payment per order, unique provider events and unique review per customer/product.
        assertThat(jdbc.queryForObject("select count(*) from pg_indexes where indexname='idx_payments_one_pending'", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("select count(*) from pg_constraint where conrelid='payment_events'::regclass and contype='u'", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("select count(*) from pg_constraint where conrelid='reviews'::regclass and contype='u'", Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("select count(*) from pg_constraint where conrelid='inventory'::regclass and contype='c'", Integer.class)).isGreaterThanOrEqualTo(1);
    }
}
