package org.spatialite;

import static org.junit.Assert.*;

import java.io.File;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;

import org.junit.BeforeClass;
import org.junit.Test;
import org.spatialite.SQLiteConfig;
import org.spatialite.SQLiteConfig.SynchronousMode;

/**
 * These tests check whether access to files is woring correctly and some
 * Connection.close() cases.
 */
public class ConnectionTest
{
    @BeforeClass
    public static void forName() throws Exception {
        Class.forName("org.spatialite.JDBC");
    }

    @Test
    public void executeUpdateOnClosedDB() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite:");
        Statement stat = conn.createStatement();
        conn.close();

        try {
            stat.executeUpdate("create table A(id, name)");
        }
        catch (SQLException e) {
            return; // successfully detect the operation on the closed DB
        }
        fail("should not reach here");
    }

    @Test
    public void readOnly() throws SQLException {
        // set read only mode
        SQLiteConfig config = new SQLiteConfig();
        config.setReadOnly(true);

        Connection conn = DriverManager.getConnection("jdbc:spatialite:", config.toProperties());
        Statement stat = conn.createStatement();
        try {
            // these updates must be forbidden in read-only mode
            stat.executeUpdate("create table A(id, name)");
            stat.executeUpdate("insert into A values(1, 'leo')");
        }
        catch (SQLException e) {
            return; // success
        }
        finally {
            stat.close();
            conn.close();
        }

        fail("read only flag is not properly set");
    }

    @Test
    public void foreignKeys() throws SQLException {
        SQLiteConfig config = new SQLiteConfig();
        config.enforceForeignKeys(true);
        Connection conn = DriverManager.getConnection("jdbc:spatialite:", config.toProperties());
        Statement stat = conn.createStatement();

        try {
            stat
                    .executeUpdate("create table track(id integer primary key, name, aid, foreign key (aid) references artist(id))");
            stat.executeUpdate("create table artist(id integer primary key, name)");

            stat.executeUpdate("insert into artist values(10, 'leo')");
            stat.executeUpdate("insert into track values(1, 'first track', 10)"); // OK

            try {
                stat.executeUpdate("insert into track values(2, 'second track', 3)"); // invalid reference
            }
            catch (SQLException e) {
                return; // successfully detect violation of foreign key constraints
            }
            fail("foreign key constraint must be enforced");
        }
        finally {
            stat.close();
            conn.close();
        }

    }

    @Test
    public void synchronous() throws SQLException {
        SQLiteConfig config = new SQLiteConfig();
        config.setSynchronous(SynchronousMode.OFF);
        Connection conn = DriverManager.getConnection("jdbc:spatialite:", config.toProperties());
        Statement stat = conn.createStatement();

        try {
            ResultSet rs = stat.executeQuery("pragma synchronous");
            if (rs.next()) {
                ResultSetMetaData rm = rs.getMetaData();
                int i = rm.getColumnCount();
                int synchronous = rs.getInt(1);
                assertEquals(0, synchronous);
            }

        }
        finally {
            stat.close();
            conn.close();
        }

    }

    @Test
    public void openMemory() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite:");
        conn.close();
    }

    @Test
    public void isClosed() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite:");
        conn.close();
        assertTrue(conn.isClosed());
    }

    @Test
    public void openFile() throws SQLException {
        File testdb = new File("test.db");
        if (testdb.exists())
            testdb.delete();
        assertFalse(testdb.exists());
        Connection conn = DriverManager.getConnection("jdbc:spatialite:test.db");
        conn.close();
        assertTrue(testdb.exists());
        testdb.delete();
    }

    @Test(expected = SQLException.class)
    public void closeTest() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite:");
        PreparedStatement prep = conn.prepareStatement("select null;");
        ResultSet rs = prep.executeQuery();
        conn.close();
        prep.clearParameters();
    }

    @Test(expected = SQLException.class)
    public void openInvalidLocation() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite:/");
        conn.close();
    }

    @Test
    public void openResource() throws SQLException {
        Connection conn = DriverManager.getConnection("jdbc:spatialite::resource:org/spatialite/sample.db");
        Statement stat = conn.createStatement();
        ResultSet rs = stat.executeQuery("select * from coordinate");
        assertTrue(rs.next());
        rs.close();
        stat.close();
        conn.close();

    }

    @Test
    public void openHttpResource() throws SQLException {
        Connection conn = DriverManager
                .getConnection("jdbc:spatialite::resource:http://www.xerial.org/svn/project/XerialJ/trunk/sqlite-jdbc/src/test/java/org/sqlite/sample.db");
        Statement stat = conn.createStatement();
        ResultSet rs = stat.executeQuery("select * from coordinate");
        assertTrue(rs.next());
        rs.close();
        stat.close();
        conn.close();

    }

    @Test
    public void openJARResource() throws SQLException {
        Connection conn = DriverManager
                .getConnection("jdbc:spatialite::resource:jar:http://www.xerial.org/svn/project/XerialJ/trunk/sqlite-jdbc/src/test/resources/testdb.jar!/sample.db");
        Statement stat = conn.createStatement();
        ResultSet rs = stat.executeQuery("select * from coordinate");
        assertTrue(rs.next());
        rs.close();
        stat.close();
        conn.close();

    }
}
