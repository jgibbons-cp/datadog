package com.appjava;

import java.io.PrintWriter;
import java.sql.Connection;
import java.io.PrintWriter;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.io.StringWriter;
import java.lang.System;

import javax.naming.NamingException;

//new
import com.mysql.cj.jdbc.MysqlDataSource;

//log4j2
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

//logback
//import org.slf4j.Logger;
//import org.slf4j.LoggerFactory;

public final class QueryEmployees {
	//log4j2
	private static final Logger logger = LogManager.getLogger(QueryEmployees.class);

	//logback
	//private static final Logger logger = LoggerFactory.getLogger(QueryEmployees.class);

	//print and log stacktrace
	static void printLogException(Exception e, PrintWriter out) {
		StringWriter writer = new StringWriter();
		PrintWriter printWriter = new PrintWriter( writer );
		e.printStackTrace( printWriter );
		printWriter.flush();

		String stackTrace = writer.toString();
		out.println(stackTrace);
		logger.error(stackTrace);
	}

  public static void query(String lastName, PrintWriter out) throws NamingException {
  	  MysqlDataSource ds = null;
			String dbHost = null;
			String db = null;
			String connString = "";
      Connection connect = null;
      PreparedStatement statement = null;
      ResultSet resultSet = null;

			//get environment variables to use different mysql dbs
			dbHost = System.getenv("DB_HOST");
			db = System.getenv("DB");

			//default to the mysql pod
			if (dbHost == null || dbHost.isEmpty()){
        dbHost = "mysql-test";
			}

			//default to sample db in pod
			if (db == null || db.isEmpty()){
				db = "employees";
			}

      try {
        // Create a new DataSource (MySQL specifically)
        // and provide the relevant information to be used by Tomcat.
        ds = new MysqlDataSource();
				connString = String.format("jdbc:mysql://%s:3306/%s", dbHost, db);
				ds.setUrl(connString);
        ds.setUser("lab");
        ds.setPassword("lab");

				connect = ds.getConnection();

				String sqlQuery = String.format("select first_name, " +
																		 "last_name FROM employees where last_name" +
																		 "= ? ");

        // Create the statement to be used to get the results.
				//validate last name
				statement = connect.prepareStatement(sqlQuery);
				statement.setString(1, lastName);

        // Execute the query and get the result set.
        resultSet = statement.executeQuery();
				out.println("<strong>Printing result using DataSource...</strong><br>");

				if(resultSet.next() == false){
					out.println("Employee Name: No Employees Matched Query<br>");
				}
				else{
	        while (resultSet.next()) {
	        	String empFirstName = resultSet.getString("first_name");
						String empLastName = resultSet.getString("last_name");
						out.println("Employee Name: " + empFirstName + "&nbsp;" + empLastName + "<br>");
	        }
				}

        logger.info("log for traceID correlation");

  			}
			catch (SQLException e)
				{
					printLogException(e, out);
				}
			catch (NullPointerException e)
				{
					printLogException(e, out);
				}
  		finally
				{
	      // Close the connection and release the resources used.
	    	try {
						resultSet.close();
					}
				catch (SQLException e)
					{
						printLogException(e, out);
					}
				catch (NullPointerException e)
					{
						printLogException(e, out);
					}
	      try {
					statement.close();
					}
				catch (SQLException e)
					{
						printLogException(e, out);
					}
				catch (NullPointerException e)
					{
						printLogException(e, out);
					}
  			}
  	}
}
